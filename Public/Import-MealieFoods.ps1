#Requires -Version 7.0
<#
.SYNOPSIS
    Import foods into Mealie from JSON files
.DESCRIPTION
    Imports food data from JSON files, creating new foods or updating existing ones.
    Supports both new wrapper format and legacy raw array format.
    Features automatic backup, household validation, and alias handling options.
.NOTES
    Part of MealieSync module - see README.md for usage examples.
#>

function Import-MealieFoods {
    <#
    .SYNOPSIS
        Import foods from a JSON file, creating new or updating existing
    .DESCRIPTION
        Imports foods from a JSON file into Mealie. Matches existing foods by:
        1) id (exact match)
        2) name/pluralName (all cross-combinations)
        3) alias (all cross-combinations)
        
        Supports the new MealieSync JSON format with $schema/$type/$version wrapper,
        as well as legacy raw array format for backward compatibility.
        
        By default, creates a backup of existing foods before import.
        By default, merges aliases (adds new aliases while keeping existing ones).
        
        When -Label is specified, only items with that label are imported from the JSON.
    .PARAMETER Path
        Path to the JSON file containing food data
    .PARAMETER Folder
        Path to a folder containing JSON files. All JSON files in the folder
        will be checked for cross-file conflicts before import, then imported
        sequentially. Conflicts will block the entire import.
    .PARAMETER Recurse
        When using -Folder, also search subdirectories for JSON files
    .PARAMETER UpdateExisting
        Update foods that already exist (matched by id, name, pluralName, or alias)
    .PARAMETER ReplaceAliases
        Replace existing aliases with new ones instead of merging
    .PARAMETER SkipBackup
        Skip the automatic backup before import
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER MatchedIds
        Hashtable tracking already-matched item IDs (for cross-file conflict detection)
    .PARAMETER Label
        Only import items with this label from the JSON file
    .PARAMETER Quiet
        Suppress console output (for preview/dry-run operations)
    .EXAMPLE
        Import-MealieFoods -Path ".\Foods.json"
        # Import new foods only (skip existing)
    .EXAMPLE
        Import-MealieFoods -Path ".\Foods.json" -UpdateExisting
        # Import and update existing foods (merge aliases)
    .EXAMPLE
        Import-MealieFoods -Path ".\Foods.json" -UpdateExisting -ReplaceAliases
        # Import and update, replacing aliases instead of merging
    .EXAMPLE
        Import-MealieFoods -Path ".\Foods.json" -Label "Groente"
        # Import only items with label "Groente"
    .EXAMPLE
        Import-MealieFoods -Path ".\Foods.json" -UpdateExisting -SkipBackup -WhatIf
        # Preview changes without backup or API calls
    .EXAMPLE
        Import-MealieFoods -Folder ".\Foods" -UpdateExisting
        # Import all JSON files from folder (checks for cross-file conflicts first)
    .EXAMPLE
        Import-MealieFoods -Folder ".\Foods" -Recurse -UpdateExisting -WhatIf
        # Preview import of all JSON files in folder and subfolders
    .OUTPUTS
        [hashtable] Statistics with Created, Updated, Unchanged, Skipped, Errors, Conflicts, LabelWarnings
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Path')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [string]$Path,
        
        [Parameter(Mandatory, ParameterSetName = 'Folder')]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Folder,
        
        [Parameter(ParameterSetName = 'Folder')]
        [switch]$Recurse,
        
        [switch]$UpdateExisting,
        
        [switch]$ReplaceAliases,
        
        [switch]$SkipBackup,
        
        [int]$ThrottleMs = 100,
        
        [hashtable]$MatchedIds,
        
        [string]$BasePath = ".",
        
        [string]$Label,
        
        [switch]$Quiet
    )
    
    #region Handle Folder Parameter Set
    
    if ($PSCmdlet.ParameterSetName -eq 'Folder') {
        # Get all JSON files in folder
        $searchParams = @{
            Path   = $Folder
            Filter = "*.json"
        }
        if ($Recurse) {
            $searchParams.Recurse = $true
        }
        $jsonFiles = @(Get-ChildItem @searchParams | Where-Object { -not $_.PSIsContainer })
        
        if ($jsonFiles.Count -eq 0) {
            Write-Warning "No JSON files found in folder: $Folder"
            return @{
                Created       = 0
                Updated       = 0
                Unchanged     = 0
                Skipped       = 0
                Errors        = 0
                LabelWarnings = 0
                Conflicts     = 0
            }
        }
        
        Write-Host ""
        Write-Host "Folder Import: $($jsonFiles.Count) JSON file(s) found" -ForegroundColor Cyan
        Write-Host "Checking for conflicts..." -ForegroundColor DarkGray
        
        # Run conflict check first
        $conflictResult = Test-MealieFoodConflicts -Path $jsonFiles.FullName -Quiet
        
        if ($conflictResult.HasConflicts) {
            # Display conflicts with full report
            Write-Host ""
            Test-MealieFoodConflicts -Path $jsonFiles.FullName
            Write-Host ""
            throw "Import aborted: $($conflictResult.ConflictCount) conflict(s) found. Fix conflicts before importing."
        }
        
        Write-Host "  No conflicts found" -ForegroundColor Green
        Write-Host ""
        
        # Process each file
        $totalStats = @{
            Created       = 0
            Updated       = 0
            Unchanged     = 0
            Skipped       = 0
            Errors        = 0
            LabelWarnings = 0
            Conflicts     = 0
        }
        
        # Shared MatchedIds across all files for import-to-import conflict detection
        $sharedMatchedIds = @{}
        
        foreach ($file in $jsonFiles) {
            Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
            
            $fileParams = @{
                Path           = $file.FullName
                UpdateExisting = $UpdateExisting
                ReplaceAliases = $ReplaceAliases
                SkipBackup     = $SkipBackup
                ThrottleMs     = $ThrottleMs
                MatchedIds     = $sharedMatchedIds
                BasePath       = $BasePath
                Quiet          = $Quiet
            }
            if ($Label) { $fileParams.Label = $Label }
            if ($WhatIfPreference) { $fileParams.WhatIf = $true }
            
            $fileStats = Import-MealieFoods @fileParams
            
            # Aggregate stats
            $totalStats.Created += $fileStats.Created
            $totalStats.Updated += $fileStats.Updated
            $totalStats.Unchanged += $fileStats.Unchanged
            $totalStats.Skipped += $fileStats.Skipped
            $totalStats.Errors += $fileStats.Errors
            $totalStats.LabelWarnings += $fileStats.LabelWarnings
            $totalStats.Conflicts += $fileStats.Conflicts
            
            # Only backup once (first file)
            $SkipBackup = $true
        }
        
        # Show combined summary
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Combined Import Summary ($($jsonFiles.Count) files)" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-ImportSummary -Stats $totalStats -Type "Foods" -WhatIf:$WhatIfPreference
        
        return $totalStats
    }
    
    #endregion Handle Folder Parameter Set
    
    #region Read and Validate Import Data
    
    # Read and validate the import file
    $importResult = Read-ImportFile -Path $Path -ExpectedType 'Foods' -ValidateHouseholds
    
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
    
    # Filter by label if specified
    if ($Label) {
        $originalCount = $importData.Count
        $importData = @($importData | Where-Object { $_.label -eq $Label })
        Write-Verbose "Filtered by label '$Label': $($importData.Count) of $originalCount items"
    }
    
    if ($importData.Count -eq 0) {
        if ($Label) {
            Write-Warning "No items found in import file with label '$Label'"
        }
        else {
            Write-Warning "No items found in import file"
        }
        return @{
            Created       = 0
            Updated       = 0
            Unchanged     = 0
            Skipped       = 0
            Errors        = 0
            LabelWarnings = 0
            Conflicts     = 0
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
    
    #region Check for Within-File Conflicts
    
    Write-Host "Checking for conflicts..." -ForegroundColor DarkGray
    
    # Build item set for conflict detection
    $itemSets = @(@{
        FilePath = $Path
        Items    = $importData
    })
    
    $conflicts = @(Find-ItemConflicts -ItemSets $itemSets -Type 'Foods')
    $summary = Get-ConflictSummary -Conflicts $conflicts -ItemSets $itemSets
    
    if ($summary.HasConflicts) {
        # Display conflicts with full report
        Format-ConflictReport -Conflicts $conflicts -Summary $summary -Type 'Foods'
        Write-Host ""
        throw "Import aborted: $($summary.ConflictCount) conflict(s) found in file. Fix conflicts before importing."
    }
    else {
        Write-Host "  No conflicts found" -ForegroundColor Green
    }
    
    #endregion Check for Within-File Conflicts

    #region Create Backup
    
    if (-not $SkipBackup -and -not $WhatIfPreference) {
        $backupPath = Backup-BeforeImport -Type 'Foods' -BasePath $BasePath
        if ($backupPath -and -not $Quiet) {
            Write-Host "Backup created: $backupPath" -ForegroundColor DarkGray
        }
    }
    
    #endregion Create Backup
    
    #region Build Lookups
    
    # Fetch existing foods and build lookup tables
    $existingFoods = Get-MealieFoods -All
    $lookups = Build-FoodLookups -Foods $existingFoods
    
    # Fetch labels and create lookup by name
    $existingLabels = Get-MealieLabels -All
    $labelsByName = @{}
    foreach ($lbl in $existingLabels) {
        $labelsByName[$lbl.name.ToLower().Trim()] = $lbl
    }
    
    #endregion Build Lookups
    
    #region Initialize Stats and Tracking
    
    $stats = New-ImportStats
    
    $total = @($importData).Count
    $current = 0
    
    # Use provided MatchedIds or create new (for cross-file conflict detection)
    if (-not $MatchedIds) {
        $MatchedIds = @{}
    }
    
    #endregion Initialize Stats and Tracking
    
    #region Process Items
    
    foreach ($item in $importData) {
        $current++
        $counter = Format-Counter -Current $current -Total $total
        
        # Skip items without a name
        if ([string]::IsNullOrWhiteSpace($item.name)) {
            Write-Warning "  $counter Skipping item with missing name"
            $stats.Errors++
            continue
        }
        
        $itemName = $item.name.Trim()
        
        # Show progress (unless Quiet mode)
        if (-not $Quiet) {
            Write-ImportProgress -Activity "Importing Foods" -Current $current -Total $total -ItemName $itemName
        }
        
        # Find existing item
        $match = Find-ExistingItem -ImportItem $item -Lookups $lookups
        $existingFood = if ($match) { $match.Item } else { $null }
        $matchMethod = if ($match) { $match.MatchMethod } else { $null }
        
        # Check for conflict (item already matched by another import item)
        if ($existingFood -and $MatchedIds.ContainsKey($existingFood.id)) {
            $previousMatch = $MatchedIds[$existingFood.id]
            if (-not $Quiet) {
                # Determine if the matched item is from Mealie or from this import batch
                $isFromImport = $existingFood._isFromImport -eq $true
                $sourceLabel = if ($isFromImport) { "import item" } else { "Mealie item" }
                $fixLocation = if ($isFromImport) { "in your import data" } else { "in Mealie" }
                
                # Show detailed conflict info explaining the actual problem
                Write-Host "  $counter " -NoNewline
                Write-Host "Conflict" -ForegroundColor Red -NoNewline
                Write-Host ": $itemName" -ForegroundColor Cyan
                
                # Core explanation: what value caused the match
                Write-Host "          Value " -NoNewline -ForegroundColor White
                Write-Host "'$($match.ImportValue)'" -NoNewline -ForegroundColor Yellow
                Write-Host " exists as $($match.MatchMethod.Split('→')[-1]) on $sourceLabel " -NoNewline -ForegroundColor White
                Write-Host "'$($existingFood.name)'" -ForegroundColor Yellow
                
                Write-Host "          But '$($existingFood.name)' was already claimed by import item " -NoNewline -ForegroundColor White
                Write-Host "'$previousMatch'" -ForegroundColor Magenta
                
                # Suggest fix based on match type
                $existingField = $match.MatchMethod.Split('→')[-1]
                if ($existingField -eq 'alias') {
                    Write-Host "          Fix: Remove '$($match.ImportValue)' from '$($existingFood.name)' aliases $fixLocation" -ForegroundColor DarkGray
                }
                elseif ($match.MatchMethod.Split('→')[0] -eq 'alias') {
                    Write-Host "          Fix: Remove '$($match.ImportValue)' from '$itemName' aliases in your import data" -ForegroundColor DarkGray
                }
                else {
                    Write-Host "          Fix: Rename one of these items in your import data, or merge them into one" -ForegroundColor DarkGray
                }
            }
            $stats.Conflicts++
            continue
        }
        
        # Track this match
        if ($existingFood) {
            $MatchedIds[$existingFood.id] = $itemName
        }
        
        # Resolve label name to labelId
        $resolvedLabelId = $null
        if (![string]::IsNullOrEmpty($item.label)) {
            $labelLookup = $labelsByName[$item.label.ToLower().Trim()]
            if ($labelLookup) {
                $resolvedLabelId = $labelLookup.id
            }
            else {
                Write-Warning "  $counter Label not found: '$($item.label)' for food '$itemName'"
                $stats.LabelWarnings++
            }
        }
        
        try {
            if ($existingFood) {
                # Existing item found
                if ($UpdateExisting) {
                    # Merge or replace aliases
                    $mergedAliases = Merge-Aliases -ExistingAliases $existingFood.aliases -NewAliases $item.aliases -ReplaceMode:$ReplaceAliases
                    
                    # Filter out aliases that match name or pluralName
                    $mergedAliases = @(Remove-RedundantAliases -Aliases $mergedAliases -Name $itemName -PluralName $item.pluralName)
                    
                    # Check if anything changed
                    $hasChanges = if ($ReplaceAliases) {
                        Test-FoodChangedReplace -Existing $existingFood -New $item -ResolvedLabelId $resolvedLabelId
                    }
                    else {
                        Test-FoodChanged -Existing $existingFood -New $item -ResolvedLabelId $resolvedLabelId -MergedAliases $mergedAliases
                    }
                    
                    if (-not $hasChanges) {
                        Write-Verbose "  $counter Unchanged: $itemName"
                        $stats.Unchanged++
                        continue
                    }
                    
                    # Build change list for display
                    $changes = Format-FoodChanges -Existing $existingFood -New $item -ResolvedLabelId $resolvedLabelId -MergedAliases $mergedAliases
                    
                    if ($WhatIfPreference) {
                        if (-not $Quiet) {
                            Write-ImportResult -Counter $counter -Result 'WouldUpdate' -ItemName $itemName -Details "(matched by $matchMethod)" -Changes $changes
                        }
                        $stats.Updated++
                    }
                    elseif ($PSCmdlet.ShouldProcess($itemName, "Update food")) {
                        # Build update data
                        $aliases = @($mergedAliases | ForEach-Object { @{ name = $_ } })
                        
                        $updateData = @{
                            name = $itemName
                        }
                        
                        if (![string]::IsNullOrEmpty($item.pluralName)) {
                            $updateData.pluralName = $item.pluralName
                        }
                        if (![string]::IsNullOrEmpty($item.description)) {
                            $updateData.description = $item.description
                        }
                        if ($aliases.Count -gt 0) {
                            $updateData.aliases = $aliases
                        }
                        if ($resolvedLabelId) {
                            $updateData.labelId = $resolvedLabelId
                        }
                        
                        Update-MealieFood -Id $existingFood.id -Data $updateData | Out-Null
                        if (-not $Quiet) {
                            Write-ImportResult -Counter $counter -Result 'Updated' -ItemName $itemName -Details "(matched by $matchMethod)" -Changes $changes
                        }
                        $stats.Updated++
                        
                        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                    }
                }
                else {
                    Write-Verbose "  $counter Skipped (exists, matched by $matchMethod): $itemName"
                    $stats.Skipped++
                }
            }
            else {
                # New item - create
                if ($WhatIfPreference) {
                    # Build changes for WhatIf display
                    $createDetails = @()
                    if (![string]::IsNullOrEmpty($item.pluralName)) {
                        $createDetails += @{ Field = "pluralName"; Old = ""; New = $item.pluralName }
                    }
                    if (![string]::IsNullOrEmpty($item.description)) {
                        $descPreview = if ($item.description.Length -gt 40) { $item.description.Substring(0, 40) + "..." } else { $item.description }
                        $createDetails += @{ Field = "description"; Old = ""; New = $descPreview }
                    }
                    if (![string]::IsNullOrEmpty($item.label)) {
                        $createDetails += @{ Field = "label"; Old = ""; New = $item.label }
                    }
                    if ($item.aliases -and $item.aliases.Count -gt 0) {
                        $aliasStr = ($item.aliases | ForEach-Object { $_.name }) -join ", "
                        $createDetails += @{ Field = "aliases"; Old = ""; New = $aliasStr }
                    }
                    
                    if (-not $Quiet) {
                        Write-ImportResult -Counter $counter -Result 'WouldCreate' -ItemName $itemName -Changes $createDetails
                    }
                    $stats.Created++
                    
                    # Add to lookups for import-to-import conflict detection
                    $simId = Add-ItemToLookups -Lookups $lookups -Item $item
                    $MatchedIds[$simId] = $itemName
                }
                elseif ($PSCmdlet.ShouldProcess($itemName, "Create food")) {
                    $aliasNames = @()
                    if ($item.aliases -and @($item.aliases).Count -gt 0) {
                        # Filter out aliases that match name or pluralName
                        $filteredAliases = Remove-RedundantAliases -Aliases $item.aliases -Name $itemName -PluralName $item.pluralName
                        $aliasNames = @($filteredAliases | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.name } })
                    }
                    
                    $params = @{
                        Name = $itemName
                    }
                    if (![string]::IsNullOrEmpty($item.pluralName)) {
                        $params.PluralName = $item.pluralName
                    }
                    if (![string]::IsNullOrEmpty($item.description)) {
                        $params.Description = $item.description
                    }
                    if ($aliasNames.Count -gt 0) {
                        $params.Aliases = $aliasNames
                    }
                    if ($resolvedLabelId) {
                        $params.LabelId = $resolvedLabelId
                    }
                    
                    New-MealieFood @params | Out-Null
                    if (-not $Quiet) {
                        Write-ImportResult -Counter $counter -Result 'Created' -ItemName $itemName
                    }
                    $stats.Created++
                    
                    # Add to lookups for import-to-import conflict detection
                    $simId = Add-ItemToLookups -Lookups $lookups -Item $item
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
    
    if (-not $Quiet) {
        Complete-ImportProgress -Activity "Importing Foods"
        Write-ImportSummary -Stats $stats -Type "Foods" -WhatIf:$WhatIfPreference
    }
    
    return $stats
    
    #endregion Finish Up
}
