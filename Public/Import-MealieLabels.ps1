#Requires -Version 7.0
<#
.SYNOPSIS
    Import labels into Mealie from JSON files
.DESCRIPTION
    Imports label data from JSON files, creating new labels or updating existing ones.
    Supports both new wrapper format and legacy raw array format.
    Features automatic backup before import.
.NOTES
    Part of MealieSync module - see README.md for usage examples.
#>

function Import-MealieLabels {
    <#
    .SYNOPSIS
        Import labels from a JSON file, creating new or updating existing
    .DESCRIPTION
        Imports labels from a JSON file into Mealie. Matches existing labels by name
        (case-insensitive).
        
        Supports the new MealieSync JSON format with $schema/$type/$version wrapper,
        as well as legacy raw array format for backward compatibility.
        
        By default, creates a backup of existing labels before import.
    .PARAMETER Path
        Path to the JSON file containing label data
    .PARAMETER UpdateExisting
        Update labels that already exist (matched by name)
    .PARAMETER SkipBackup
        Skip the automatic backup before import
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .EXAMPLE
        Import-MealieLabels -Path ".\Labels.json"
        # Import new labels only (skip existing)
    .EXAMPLE
        Import-MealieLabels -Path ".\Labels.json" -UpdateExisting
        # Import and update existing labels
    .EXAMPLE
        Import-MealieLabels -Path ".\Labels.json" -UpdateExisting -WhatIf
        # Preview changes without making API calls
    .OUTPUTS
        [hashtable] Statistics with Created, Updated, Unchanged, Skipped, Errors
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$UpdateExisting,
        
        [switch]$SkipBackup,
        
        [int]$ThrottleMs = 100,
        
        [string]$BasePath = "."
    )
    
    #region Read and Validate Import Data
    
    # Read and validate the import file
    $importResult = Read-ImportFile -Path $Path -ExpectedType 'Labels'
    
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
        $backupPath = Backup-BeforeImport -Type 'Labels' -BasePath $BasePath
        if ($backupPath) {
            Write-Host "Backup created: $backupPath" -ForegroundColor DarkGray
        }
    }
    
    #endregion Create Backup
    
    #region Build Lookups
    
    # Fetch existing labels and build lookup by name
    $existingLabels = Get-MealieLabels -All
    $existingByName = @{}
    foreach ($label in $existingLabels) {
        $existingByName[$label.name.ToLower().Trim()] = $label
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
        Write-ImportProgress -Activity "Importing Labels" -Current $current -Total $total -ItemName $itemName
        
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
                    if (-not (Test-LabelChanged -Existing $existingItem -New $item)) {
                        Write-Verbose "  $counter Unchanged: $itemName"
                        $stats.Unchanged++
                        continue
                    }
                    
                    # Build change list for display
                    $changes = @()
                    if (-not (Compare-StringValue $existingItem.color $item.color) -and ![string]::IsNullOrEmpty($item.color)) {
                        $changes += @{ Field = "color"; Old = $existingItem.color; New = $item.color }
                    }
                    
                    if ($WhatIfPreference) {
                        Write-ImportResult -Counter $counter -Result 'WouldUpdate' -ItemName $itemName -Changes $changes
                        $stats.Updated++
                    }
                    elseif ($PSCmdlet.ShouldProcess($itemName, "Update Label")) {
                        $updateData = @{
                            name    = $itemName
                            groupId = $existingItem.groupId  # Required by API
                        }
                        if (![string]::IsNullOrEmpty($item.color)) {
                            $updateData.color = $item.color
                        }
                        
                        Update-MealieLabel -Id $existingItem.id -Data $updateData | Out-Null
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
                    if (![string]::IsNullOrEmpty($item.color)) {
                        $createDetails += @{ Field = "color"; Old = ""; New = $item.color }
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
                elseif ($PSCmdlet.ShouldProcess($itemName, "Create Label")) {
                    $color = if (![string]::IsNullOrEmpty($item.color)) { $item.color } else { "#1976D2" }
                    New-MealieLabel -Name $itemName -Color $color | Out-Null
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
    
    Complete-ImportProgress -Activity "Importing Labels"
    Write-ImportSummary -Stats $stats -Type "Labels" -WhatIf:$WhatIfPreference
    
    return $stats
    
    #endregion Finish Up
}
