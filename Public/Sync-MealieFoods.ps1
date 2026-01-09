#Requires -Version 7.0
<#
.SYNOPSIS
    Sync (mirror) foods in Mealie to match a JSON file exactly
.DESCRIPTION
    Synchronizes Mealie foods to exactly match the contents of a JSON file.
    This includes adding new items, updating existing items, AND deleting
    items that exist in Mealie but not in the JSON file.
    
    WARNING: This operation is destructive - it will DELETE foods from Mealie
    that are not present in the import file.
.NOTES
    Part of MealieSync module - see README.md for usage examples.
#>

function Sync-MealieFoods {
    <#
    .SYNOPSIS
        Sync foods to exactly match a JSON file (add, update, AND delete)
    .DESCRIPTION
        Performs a full synchronization of Mealie foods to match the JSON file:
        1. Creates new foods that exist in JSON but not in Mealie
        2. Updates existing foods that have changes
        3. DELETES foods that exist in Mealie but not in the JSON file
        
        This is a destructive operation. Use -WhatIf to preview changes safely.
        
        When -Label is specified, deletions are scoped to only items with that label.
        Items with other labels (or no label) are not deleted.
        
        Confirmation Flow:
        - Default: Preview → Prompt → Execute if confirmed
        - With -WhatIf: Preview only (no prompt, no changes)
        - With -Force: Execute immediately (no preview, no prompt)
        
        By default, creates a backup before making any changes.
    .PARAMETER Path
        Path to the JSON file containing food data
    .PARAMETER Folder
        Path to a folder containing JSON files. All JSON files in the folder
        will be checked for cross-file conflicts before sync, then synced
        sequentially. Conflicts will block the entire sync operation.
    .PARAMETER Recurse
        When using -Folder, also search subdirectories for JSON files
    .PARAMETER Label
        Scope deletions to only items with this label. Items with other labels
        will not be deleted, even if they're not in the JSON file.
    .PARAMETER ReplaceAliases
        Replace existing aliases with new ones instead of merging
    .PARAMETER SkipBackup
        Skip the automatic backup before sync
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER Force
        Skip preview and confirmation prompt - execute immediately
    .EXAMPLE
        Sync-MealieFoods -Path ".\Foods.json" -WhatIf
        # Preview what would be added, updated, and DELETED
    .EXAMPLE
        Sync-MealieFoods -Path ".\Groente.json" -Label "Groente"
        # Sync only Groente items - other labels are untouched
    .EXAMPLE
        Sync-MealieFoods -Path ".\Foods.json" -Force
        # Full sync without preview or confirmation prompt
    .EXAMPLE
        Sync-MealieFoods -Folder ".\Foods" -WhatIf
        # Preview sync of all JSON files in folder (checks for cross-file conflicts first)
    .EXAMPLE
        Sync-MealieFoods -Folder ".\Foods" -Recurse -Force
        # Sync all JSON files in folder and subfolders without confirmation
    .OUTPUTS
        [hashtable] Statistics with Created, Updated, Unchanged, Skipped, Errors, Conflicts, Deleted
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'Path')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [string]$Path,
        
        [Parameter(Mandatory, ParameterSetName = 'Folder')]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Folder,
        
        [Parameter(ParameterSetName = 'Folder')]
        [switch]$Recurse,
        
        [string]$Label,
        
        [switch]$ReplaceAliases,
        
        [switch]$SkipBackup,
        
        [int]$ThrottleMs = 100,
        
        [switch]$Force,
        
        [string]$BasePath = "."
    )
    
    # Override ConfirmPreference if -Force is specified
    if ($Force) {
        $ConfirmPreference = 'None'
    }
    
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
                Deleted       = 0
            }
        }
        
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║  FOLDER SYNC MODE - Processing $($jsonFiles.Count.ToString().PadLeft(3)) file(s)                    ║" -ForegroundColor Cyan
        Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Checking for conflicts..." -ForegroundColor DarkGray
        
        # Run conflict check first
        $conflictResult = Test-MealieFoodConflicts -Path $jsonFiles.FullName -Quiet
        
        if ($conflictResult.HasConflicts) {
            # Display conflicts with full report
            Test-MealieFoodConflicts -Path $jsonFiles.FullName
            Write-Host ""
            throw "Sync aborted: $($conflictResult.ConflictCount) conflict(s) found. Fix conflicts before syncing."
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
            Deleted       = 0
        }
        
        $firstFile = $true
        foreach ($file in $jsonFiles) {
            Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
            Write-Host "  Syncing: $($file.Name)" -ForegroundColor Cyan
            Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
            
            $fileParams = @{
                Path           = $file.FullName
                ReplaceAliases = $ReplaceAliases
                SkipBackup     = (-not $firstFile) -or $SkipBackup
                ThrottleMs     = $ThrottleMs
                Force          = $Force
                BasePath       = $BasePath
            }
            if ($Label) { $fileParams.Label = $Label }
            if ($WhatIfPreference) { $fileParams.WhatIf = $true }
            
            $fileStats = Sync-MealieFoods @fileParams
            
            # Check if user cancelled
            if ($fileStats.Cancelled) {
                Write-Host ""
                Write-Host "Folder sync cancelled by user." -ForegroundColor Yellow
                return $totalStats
            }
            
            # Aggregate stats
            $totalStats.Created += $fileStats.Created
            $totalStats.Updated += $fileStats.Updated
            $totalStats.Unchanged += $fileStats.Unchanged
            $totalStats.Skipped += $fileStats.Skipped
            $totalStats.Errors += $fileStats.Errors
            $totalStats.LabelWarnings += $fileStats.LabelWarnings
            $totalStats.Conflicts += $fileStats.Conflicts
            $totalStats.Deleted += $fileStats.Deleted
            
            $firstFile = $false
        }
        
        # Show combined summary
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Combined Sync Summary ($($jsonFiles.Count) files)" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-SyncSummary -ImportStats $totalStats -DeletedCount $totalStats.Deleted -Type "Foods" -WhatIf:$WhatIfPreference
        
        return $totalStats
    }
    
    #endregion Handle Folder Parameter Set
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  SYNC MODE - This will ADD, UPDATE, and DELETE foods          ║" -ForegroundColor Cyan
    if ($Label) {
        Write-Host "║  " -ForegroundColor Cyan -NoNewline
        Write-Host ("Label scope: $Label".PadRight(59)) -ForegroundColor Yellow -NoNewline
        Write-Host "║" -ForegroundColor Cyan
        Write-Host "║  " -ForegroundColor Cyan -NoNewline
        Write-Host ("(Only '$Label' items will be deleted)".PadRight(59)) -ForegroundColor Yellow -NoNewline
        Write-Host "║" -ForegroundColor Cyan
    }
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    #region Read and Validate Import Data
    
    # Read the import file (validation happens inside)
    $importResult = Read-ImportFile -Path $Path -ExpectedType 'Foods' -ValidateHouseholds
    
    if (-not $importResult.ValidationResult.Valid) {
        foreach ($err in $importResult.ValidationResult.Errors) {
            Write-Error $err
        }
        throw "Import validation failed. See errors above."
    }
    
    foreach ($warning in $importResult.ValidationResult.Warnings) {
        Write-Warning $warning
    }
    
    $importData = $importResult.Items
    
    # Filter import data by label if specified (for deletion comparison)
    $filteredImportData = if ($Label) {
        $filtered = @($importData | Where-Object { $_.label -eq $Label })
        if ($filtered.Count -eq 0) {
            Write-Warning "No items found in import file with label '$Label'"
            Write-Warning "Check that the label name matches exactly (case-insensitive)"
        }
        $filtered
    }
    else {
        $importData
    }
    
    # Ensure we have an array (not null)
    if ($null -eq $filteredImportData) {
        $filteredImportData = @()
    }
    
    #endregion Read and Validate Import Data
    
    #region Check for Within-File Conflicts
    
    Write-Host "Checking for conflicts..." -ForegroundColor DarkGray
    
    # Build item set for conflict detection
    $itemSets = @(@{
        FilePath = $Path
        Items    = $importData
    })
    
    $conflicts = Find-ItemConflicts -ItemSets $itemSets -Type 'Foods'
    $summary = Get-ConflictSummary -Conflicts $conflicts -ItemSets $itemSets
    
    if ($summary.HasConflicts) {
        # Display conflicts with full report
        Format-ConflictReport -Conflicts $conflicts -Summary $summary -Type 'Foods'
        Write-Host ""
        throw "Sync aborted: $($summary.ConflictCount) conflict(s) found in file. Fix conflicts before syncing."
    }
    else {
        Write-Host "  No conflicts found" -ForegroundColor Green
    }
    
    #endregion Check for Within-File Conflicts

    #region Create Backup
    
    $backupPath = $null
    if (-not $SkipBackup -and -not $WhatIfPreference) {
        $backupPath = Backup-BeforeImport -Type 'Foods' -BasePath $BasePath
        if ($backupPath) {
            Write-Host "Backup created: $backupPath" -ForegroundColor DarkGray
        }
    }
    
    #endregion Create Backup
    
    #region Preview Phase (unless -Force)
    
    # Items to delete (calculated once, used in preview and execution)
    $toDelete = @()
    
    if (-not $Force) {
        Write-Host "Analyzing changes..." -ForegroundColor Cyan
        
        # Run import in preview mode to get stats (silently)
        $previewParams = @{
            Path           = $Path
            UpdateExisting = $true
            SkipBackup     = $true
            ThrottleMs     = 0  # No throttle needed for preview
            BasePath       = $BasePath
            WhatIf         = $true
            Quiet          = $true
        }
        if ($ReplaceAliases) { $previewParams.ReplaceAliases = $true }
        if ($Label) { $previewParams.Label = $Label }
        
        $importPreview = Import-MealieFoods @previewParams
        
        # Get deletion candidates from current Mealie state
        $existingFoods = Get-MealieFoods -All
        
        if ($Label) {
            $deletionCandidates = @($existingFoods | Where-Object { 
                $_.label -and $_.label.name -eq $Label 
            })
        }
        else {
            $deletionCandidates = $existingFoods
        }
        
        # Find items to delete (exist in Mealie but not in import)
        $toDelete = @(Get-ItemsToDelete -ExistingItems $deletionCandidates -ImportItems $filteredImportData -MatchById)
        
        # Check recipe usage for items to be deleted
        if ($toDelete.Count -gt 0) {
            Write-Host "  Checking recipe usage for $($toDelete.Count) item(s) to delete..." -ForegroundColor DarkGray
            $usageResult = Test-FoodsInUse -Foods $toDelete
            
            if ($usageResult.HasUsedItems) {
                Show-RecipeUsageWarning -UsageResult $usageResult
                
                # Filter to only safe-to-delete items
                $safeIds = $usageResult.SafeToDelete | ForEach-Object { $_.Id }
                $toDelete = @($toDelete | Where-Object { $_.id -in $safeIds })
            }
        }
        
        # Show preview summary
        Show-MirrorPreview -ImportPreview $importPreview -DeleteItems $toDelete -Type 'Foods' -Label $Label -BackupPath $backupPath
        
        # If -WhatIf, stop here (preview only)
        if ($WhatIfPreference) {
            $importPreview.Deleted = @($toDelete).Count
            return $importPreview
        }
        
        # Prompt for confirmation
        $confirmed = Request-MirrorConfirmation -DeleteCount @($toDelete).Count -CreateCount $importPreview.Created -UpdateCount $importPreview.Updated
        
        if (-not $confirmed) {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            return @{
                Created       = 0
                Updated       = 0
                Unchanged     = 0
                Skipped       = 0
                Errors        = 0
                Conflicts     = 0
                Deleted       = 0
                LabelWarnings = 0
                Cancelled     = $true
            }
        }
        
        Write-Host ""
    }
    
    #endregion Preview Phase
    
    #region Execute Phase
    
    Write-Host "Executing changes..." -ForegroundColor Cyan
    
    # Phase 1: Import (Add/Update)
    Write-Host ""
    Write-Host "Phase 1: Importing (add/update)..." -ForegroundColor Cyan
    
    $importParams = @{
        Path           = $Path
        UpdateExisting = $true
        SkipBackup     = $true  # Already did backup
        ThrottleMs     = $ThrottleMs
        BasePath       = $BasePath
    }
    if ($ReplaceAliases) { $importParams.ReplaceAliases = $true }
    if ($Label) { $importParams.Label = $Label }
    
    $importStats = Import-MealieFoods @importParams
    
    # Phase 2: Delete Orphans
    Write-Host ""
    Write-Host "Phase 2: Deleting orphaned items..." -ForegroundColor Cyan
    
    # If -Force, we need to calculate deletions now (wasn't done in preview)
    if ($Force) {
        $existingFoods = Get-MealieFoods -All
        
        if ($Label) {
            $deletionCandidates = @($existingFoods | Where-Object { 
                $_.label -and $_.label.name -eq $Label 
            })
        }
        else {
            $deletionCandidates = $existingFoods
        }
        
        $toDelete = @(Get-ItemsToDelete -ExistingItems $deletionCandidates -ImportItems $filteredImportData -MatchById)
        
        # Check recipe usage for items to be deleted
        if ($toDelete.Count -gt 0) {
            Write-Host "  Checking recipe usage for $($toDelete.Count) item(s) to delete..." -ForegroundColor DarkGray
            $usageResult = Test-FoodsInUse -Foods $toDelete
            
            if ($usageResult.HasUsedItems) {
                Show-RecipeUsageWarning -UsageResult $usageResult
                
                # Filter to only safe-to-delete items
                $safeIds = $usageResult.SafeToDelete | ForEach-Object { $_.Id }
                $toDelete = @($toDelete | Where-Object { $_.id -in $safeIds })
            }
        }
    }
    
    $deleteCount = @($toDelete).Count
    
    if ($deleteCount -eq 0) {
        Write-Host "  No orphaned items to delete." -ForegroundColor DarkGray
        $deletedCount = 0
    }
    else {
        Write-Host "  Deleting $deleteCount item(s)..." -ForegroundColor Magenta
        Write-Host ""
        
        # Execute deletions (user already confirmed, so skip per-item ShouldProcess)
        $deletedCount = 0
        $current = 0
        
        foreach ($item in $toDelete) {
            $current++
            $counter = Format-Counter -Current $current -Total $deleteCount
            
            try {
                Remove-MealieFood -Id $item.id | Out-Null
                Write-ImportResult -Counter $counter -Result 'Deleted' -ItemName $item.name
                $deletedCount++
                
                if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
            }
            catch {
                Write-Warning "  $counter Error deleting '$($item.name)': $_"
            }
        }
    }
    
    #endregion Execute Phase
    
    #region Summary
    
    Write-SyncSummary -ImportStats $importStats -DeletedCount $deletedCount -Type "Foods"
    
    # Return combined stats
    $importStats.Deleted = $deletedCount
    return $importStats
    
    #endregion Summary
}
