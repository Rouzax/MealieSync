#Requires -Version 7.0
<#
.SYNOPSIS
    Import organizers (categories, tags, tools) into Mealie from JSON files
.DESCRIPTION
    Imports organizer data from JSON files, creating new items or updating existing ones.
    Supports both new wrapper format and legacy raw array format.
    Features automatic backup and household validation for tools.
.NOTES
    Part of MealieSync module - see README.md for usage examples.
#>

function Import-MealieOrganizers {
    <#
    .SYNOPSIS
        Import categories, tags, or tools from a JSON file
    .DESCRIPTION
        Imports organizers from a JSON file into Mealie. Matches existing items by name
        (case-insensitive).
        
        Supports the new MealieSync JSON format with $schema/$type/$version wrapper,
        as well as legacy raw array format for backward compatibility.
        
        For Tools, validates household names upfront before import.
        By default, creates a backup of existing data before import.
    .PARAMETER Path
        Path to the JSON file containing organizer data
    .PARAMETER Type
        Type of organizer: Categories, Tags, or Tools
    .PARAMETER UpdateExisting
        Update items that already exist (matched by name)
    .PARAMETER SkipBackup
        Skip the automatic backup before import
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .EXAMPLE
        Import-MealieOrganizers -Path ".\Categories.json" -Type Categories
        # Import new categories only
    .EXAMPLE
        Import-MealieOrganizers -Path ".\Tools.json" -Type Tools -UpdateExisting
        # Import and update existing tools
    .EXAMPLE
        Import-MealieOrganizers -Path ".\Tags.json" -Type Tags -WhatIf
        # Preview changes without making API calls
    .OUTPUTS
        [hashtable] Statistics with Created, Updated, Unchanged, Skipped, Errors
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [ValidateSet('Categories', 'Tags', 'Tools')]
        [string]$Type,
        
        [switch]$UpdateExisting,
        
        [switch]$SkipBackup,
        
        [int]$ThrottleMs = 100,
        
        [string]$BasePath = "."
    )
    
    #region Read and Validate Import Data
    
    # Read and validate the import file
    # For Tools, validate households upfront
    $validateHouseholds = ($Type -eq 'Tools')
    $importResult = Read-ImportFile -Path $Path -ExpectedType $Type -ValidateHouseholds:$validateHouseholds
    
    # Check for validation errors
    if (-not $importResult.ValidationResult.Valid) {
        Write-Host ""
        foreach ($err in $importResult.ValidationResult.Errors) {
            Write-Host "ERROR: $err" -ForegroundColor Red
        }
        Write-Host ""
        throw "Import validation failed."
    }
    
    # Show warnings
    foreach ($warning in $importResult.ValidationResult.Warnings) {
        Write-Warning $warning
    }
    
    $importData = $importResult.Items
    
    if ($importData.Count -eq 0) {
        Write-Warning "No items found in import file"
        return @{
            Created   = 0
            Updated   = 0
            Unchanged = 0
            Skipped   = 0
            Errors    = 0
        }
    }
    
    # Log format detection
    if ($importResult.IsNewFormat) {
        Write-Verbose "Detected new JSON format with wrapper"
    }
    else {
        Write-Verbose "Detected legacy JSON format (raw array)"
    }
    
    #endregion Read and Validate Import Data
    
    #region Create Backup
    
    if (-not $SkipBackup -and -not $WhatIfPreference) {
        $backupPath = Backup-BeforeImport -Type $Type -BasePath $BasePath
        if ($backupPath) {
            Write-Host "Backup created: $backupPath" -ForegroundColor DarkGray
        }
    }
    
    #endregion Create Backup
    
    #region Build Lookups
    
    # Fetch existing items and build lookup by name
    $existingItems = switch ($Type) {
        'Categories' { Get-MealieCategories -All }
        'Tags' { Get-MealieTags -All }
        'Tools' { Get-MealieTools -All }
    }
    
    $existingByName = @{}
    foreach ($item in $existingItems) {
        $existingByName[$item.name.ToLower().Trim()] = $item
    }
    
    # Track which items have been matched (for conflict detection)
    $MatchedIds = @{}
    
    #endregion Build Lookups
    
    #region Initialize Stats
    
    $stats = New-ImportStats
    
    $total = @($importData).Count
    $current = 0
    
    #endregion Initialize Stats
    
    #region Process Items
    
    foreach ($item in $importData) {
        $current++
        $counter = Format-Counter -Current $current -Total $total
        $itemName = $item.name.Trim()
        
        # Show progress
        Write-ImportProgress -Activity "Importing $Type" -Current $current -Total $total -ItemName $itemName
        
        # Find existing item
        $existingItem = $existingByName[$itemName.ToLower()]
        
        # Check for conflict (item already matched by another import item)
        if ($existingItem -and $MatchedIds.ContainsKey($existingItem.id)) {
            $previousMatch = $MatchedIds[$existingItem.id]
            $isFromImport = $existingItem._isFromImport -eq $true
            $sourceLabel = if ($isFromImport) { "import item" } else { "Mealie item" }
            
            Write-Host "  $counter " -NoNewline
            Write-Host "Conflict" -ForegroundColor Red -NoNewline
            Write-Host ": $itemName" -ForegroundColor Cyan
            Write-Host "          Name '$itemName' matches $sourceLabel " -NoNewline -ForegroundColor White
            Write-Host "'$($existingItem.name)'" -ForegroundColor Yellow
            Write-Host "          But '$($existingItem.name)' was already claimed by import item " -NoNewline -ForegroundColor White
            Write-Host "'$previousMatch'" -ForegroundColor Magenta
            Write-Host "          Fix: Remove duplicate '$itemName' from your import data" -ForegroundColor DarkGray
            
            $stats.Conflicts++
            continue
        }
        
        # Track this match
        if ($existingItem) {
            $MatchedIds[$existingItem.id] = $itemName
        }
        
        try {
            if ($existingItem) {
                # Existing item found
                if ($UpdateExisting) {
                    # Check if anything changed
                    $hasChanges = if ($Type -eq 'Tools') {
                        Test-ToolChanged -Existing $existingItem -New $item
                    }
                    else {
                        Test-OrganizerChanged -Existing $existingItem -New $item
                    }
                    
                    if (-not $hasChanges) {
                        Write-Verbose "  $counter Unchanged: $itemName"
                        $stats.Unchanged++
                        continue
                    }
                    
                    # Build change list for display
                    $changes = @()
                    if ($Type -eq 'Tools' -and $item.householdsWithTool) {
                        $existingHouseholds = if ($existingItem.householdsWithTool) { $existingItem.householdsWithTool -join ", " } else { "(none)" }
                        $newHouseholds = $item.householdsWithTool -join ", "
                        if ($existingHouseholds -ne $newHouseholds) {
                            $changes += @{ Field = "households"; Old = $existingHouseholds; New = $newHouseholds }
                        }
                    }
                    
                    if ($WhatIfPreference) {
                        Write-ImportResult -Counter $counter -Result 'WouldUpdate' -ItemName $itemName -Changes $changes
                        $stats.Updated++
                    }
                    elseif ($PSCmdlet.ShouldProcess($itemName, "Update $Type")) {
                        $updateData = @{
                            name    = $itemName
                            groupId = $existingItem.groupId  # Required by API
                        }
                        
                        # Tools: include householdsWithTool
                        if ($Type -eq 'Tools' -and $item.householdsWithTool) {
                            $updateData.householdsWithTool = $item.householdsWithTool
                        }
                        
                        switch ($Type) {
                            'Categories' { Update-MealieCategory -Id $existingItem.id -Data $updateData | Out-Null }
                            'Tags' { Update-MealieTag -Id $existingItem.id -Data $updateData | Out-Null }
                            'Tools' { Update-MealieTool -Id $existingItem.id -Data $updateData | Out-Null }
                        }
                        
                        Write-ImportResult -Counter $counter -Result 'Updated' -ItemName $itemName
                        $stats.Updated++
                        
                        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                    }
                }
                else {
                    Write-Verbose "  $counter Skipped (exists): $itemName"
                    $stats.Skipped++
                }
            }
            else {
                # New item - create
                if ($WhatIfPreference) {
                    $createDetails = @()
                    if ($Type -eq 'Tools' -and $item.householdsWithTool -and $item.householdsWithTool.Count -gt 0) {
                        $createDetails += @{ Field = "households"; Old = ""; New = ($item.householdsWithTool -join ", ") }
                    }
                    Write-ImportResult -Counter $counter -Result 'WouldCreate' -ItemName $itemName -Changes $createDetails
                    $stats.Created++
                    
                    # Add to lookups for import-to-import conflict detection
                    $simId = [guid]::NewGuid().ToString()
                    $existingByName[$itemName.ToLower()] = @{
                        id            = $simId
                        name          = $itemName
                        _isFromImport = $true
                    }
                    $MatchedIds[$simId] = $itemName
                }
                elseif ($PSCmdlet.ShouldProcess($itemName, "Create $Type")) {
                    switch ($Type) {
                        'Categories' { New-MealieCategory -Name $itemName | Out-Null }
                        'Tags' { New-MealieTag -Name $itemName | Out-Null }
                        'Tools' {
                            # Tools may have householdsWithTool
                            if ($item.householdsWithTool -and $item.householdsWithTool.Count -gt 0) {
                                New-MealieTool -Name $itemName -Households $item.householdsWithTool | Out-Null
                            }
                            else {
                                New-MealieTool -Name $itemName | Out-Null
                            }
                        }
                    }
                    
                    Write-ImportResult -Counter $counter -Result 'Created' -ItemName $itemName
                    $stats.Created++
                    
                    # Add to lookups for import-to-import conflict detection
                    $simId = [guid]::NewGuid().ToString()
                    $existingByName[$itemName.ToLower()] = @{
                        id            = $simId
                        name          = $itemName
                        _isFromImport = $true
                    }
                    $MatchedIds[$simId] = $itemName
                    
                    if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                }
            }
        }
        catch {
            Write-Warning "  $counter Error processing '$itemName': $_"
            $stats.Errors++
        }
    }
    
    #endregion Process Items
    
    #region Finish Up
    
    Complete-ImportProgress -Activity "Importing $Type"
    Write-ImportSummary -Stats $stats -Type $Type -WhatIf:$WhatIfPreference
    
    return $stats
    
    #endregion Finish Up
}

#region Convenience Wrappers

function Import-MealieCategories {
    <#
    .SYNOPSIS
        Import categories from a JSON file (convenience wrapper)
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER UpdateExisting
        Update categories that already exist
    .PARAMETER SkipBackup
        Skip the automatic backup before import
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$UpdateExisting,
        
        [switch]$SkipBackup,
        
        [int]$ThrottleMs = 100
    )
    
    Import-MealieOrganizers -Path $Path -Type 'Categories' -UpdateExisting:$UpdateExisting -SkipBackup:$SkipBackup -ThrottleMs $ThrottleMs
}

function Import-MealieTags {
    <#
    .SYNOPSIS
        Import tags from a JSON file (convenience wrapper)
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER UpdateExisting
        Update tags that already exist
    .PARAMETER SkipBackup
        Skip the automatic backup before import
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$UpdateExisting,
        
        [switch]$SkipBackup,
        
        [int]$ThrottleMs = 100
    )
    
    Import-MealieOrganizers -Path $Path -Type 'Tags' -UpdateExisting:$UpdateExisting -SkipBackup:$SkipBackup -ThrottleMs $ThrottleMs
}

function Import-MealieTools {
    <#
    .SYNOPSIS
        Import tools from a JSON file (convenience wrapper)
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER UpdateExisting
        Update tools that already exist
    .PARAMETER SkipBackup
        Skip the automatic backup before import
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$UpdateExisting,
        
        [switch]$SkipBackup,
        
        [int]$ThrottleMs = 100
    )
    
    Import-MealieOrganizers -Path $Path -Type 'Tools' -UpdateExisting:$UpdateExisting -SkipBackup:$SkipBackup -ThrottleMs $ThrottleMs
}

#endregion Convenience Wrappers
