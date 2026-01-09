#Requires -Version 7.0
<#
.SYNOPSIS
    Sync (mirror) units in Mealie to match a JSON file exactly
.DESCRIPTION
    Synchronizes Mealie units to exactly match the contents of a JSON file.
    This includes adding new items, updating existing items, AND deleting
    items that exist in Mealie but not in the JSON file.
    
    WARNING: This operation is destructive - it will DELETE units from Mealie
    that are not present in the import file.
.NOTES
    Part of MealieSync module - see README.md for usage examples.
#>

function Sync-MealieUnits {
    <#
    .SYNOPSIS
        Sync units to exactly match a JSON file (add, update, AND delete)
    .DESCRIPTION
        Performs a full synchronization of Mealie units to match the JSON file:
        1. Creates new units that exist in JSON but not in Mealie
        2. Updates existing units that have changes
        3. DELETES units that exist in Mealie but not in the JSON file
        
        This is a destructive operation. Use -WhatIf to preview changes safely.
    .PARAMETER Path
        Path to the JSON file containing unit data
    .PARAMETER Folder
        Path to a folder containing JSON files. All JSON files in the folder
        will be checked for cross-file conflicts before sync, then synced
        sequentially. Conflicts will block the entire sync operation.
    .PARAMETER Recurse
        When using -Folder, also search subdirectories for JSON files
    .PARAMETER ReplaceAliases
        Replace existing aliases with new ones instead of merging
    .PARAMETER SkipBackup
        Skip the automatic backup before sync
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER Force
        Skip confirmation prompt for deletions
    .EXAMPLE
        Sync-MealieUnits -Path ".\Units.json" -WhatIf
        # Preview what would be added, updated, and DELETED
    .EXAMPLE
        Sync-MealieUnits -Folder ".\Units" -WhatIf
        # Preview sync of all JSON files in folder (checks for cross-file conflicts first)
    .EXAMPLE
        Sync-MealieUnits -Folder ".\Units" -Recurse -Force
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
        
        [switch]$ReplaceAliases,
        
        [switch]$SkipBackup,
        
        [int]$ThrottleMs = 100,
        
        [switch]$Force,
        
        [string]$BasePath = "."
    )
    
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
                Created   = 0
                Updated   = 0
                Unchanged = 0
                Skipped   = 0
                Errors    = 0
                Conflicts = 0
                Deleted   = 0
            }
        }
        
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║  FOLDER SYNC MODE - Processing $($jsonFiles.Count.ToString().PadLeft(3)) file(s)                    ║" -ForegroundColor Cyan
        Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Checking for conflicts..." -ForegroundColor DarkGray
        
        # Run conflict check first
        $conflictResult = Test-MealieUnitConflicts -Path $jsonFiles.FullName -Quiet
        
        if ($conflictResult.HasConflicts) {
            # Display conflicts with full report
            Test-MealieUnitConflicts -Path $jsonFiles.FullName
            Write-Host ""
            throw "Sync aborted: $($conflictResult.ConflictCount) conflict(s) found. Fix conflicts before syncing."
        }
        
        Write-Host "  No conflicts found" -ForegroundColor Green
        Write-Host ""
        
        # Process each file
        $totalStats = @{
            Created   = 0
            Updated   = 0
            Unchanged = 0
            Skipped   = 0
            Errors    = 0
            Conflicts = 0
            Deleted   = 0
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
            if ($WhatIfPreference) { $fileParams.WhatIf = $true }
            
            $fileStats = Sync-MealieUnits @fileParams
            
            # Aggregate stats
            $totalStats.Created += $fileStats.Created
            $totalStats.Updated += $fileStats.Updated
            $totalStats.Unchanged += $fileStats.Unchanged
            $totalStats.Skipped += $fileStats.Skipped
            $totalStats.Errors += $fileStats.Errors
            $totalStats.Conflicts += $fileStats.Conflicts
            $totalStats.Deleted += $fileStats.Deleted
            
            $firstFile = $false
        }
        
        # Show combined summary
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Combined Sync Summary ($($jsonFiles.Count) files)" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-SyncSummary -ImportStats $totalStats -DeletedCount $totalStats.Deleted -Type "Units" -WhatIf:$WhatIfPreference
        
        return $totalStats
    }
    
    #endregion Handle Folder Parameter Set
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  SYNC MODE - This will ADD, UPDATE, and DELETE units          ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    #region Read and Validate
    
    $importResult = Read-ImportFile -Path $Path -ExpectedType 'Units'
    
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
    
    #endregion Read and Validate
    
    #region Check for Within-File Conflicts
    
    Write-Host "Checking for conflicts..." -ForegroundColor DarkGray
    
    # Build item set for conflict detection
    $itemSets = @(@{
        FilePath = $Path
        Items    = $importData
    })
    
    $conflicts = Find-ItemConflicts -ItemSets $itemSets -Type 'Units'
    $summary = Get-ConflictSummary -Conflicts $conflicts -ItemSets $itemSets
    
    if ($summary.HasConflicts) {
        # Display conflicts with full report
        Format-ConflictReport -Conflicts $conflicts -Summary $summary -Type 'Units'
        Write-Host ""
        throw "Sync aborted: $($summary.ConflictCount) conflict(s) found in file. Fix conflicts before syncing."
    }
    else {
        Write-Host "  No conflicts found" -ForegroundColor Green
    }
    
    #endregion Check for Within-File Conflicts

    #region Create Backup
    
    if (-not $SkipBackup -and -not $WhatIfPreference) {
        $backupPath = Backup-BeforeImport -Type 'Units' -BasePath $BasePath
        if ($backupPath) {
            Write-Host "Backup created: $backupPath" -ForegroundColor DarkGray
        }
    }
    
    #endregion Create Backup
    
    #region Phase 1: Import
    
    Write-Host ""
    Write-Host "Phase 1: Importing (add/update)..." -ForegroundColor Cyan
    
    $importStats = Import-MealieUnits -Path $Path -UpdateExisting -ReplaceAliases:$ReplaceAliases -SkipBackup -ThrottleMs $ThrottleMs
    
    #endregion Phase 1: Import
    
    #region Phase 2: Delete Orphans
    
    Write-Host ""
    Write-Host "Phase 2: Finding orphaned items..." -ForegroundColor Cyan
    
    $existingUnits = Get-MealieUnits -All
    $toDelete = Get-ItemsToDelete -ExistingItems $existingUnits -ImportItems $importData -MatchById
    
    $deleteCount = @($toDelete).Count
    
    if ($deleteCount -eq 0) {
        Write-Host "  No orphaned items to delete." -ForegroundColor DarkGray
        $deletedCount = 0
    }
    else {
        Write-Host ""
        Write-Host "  Found $deleteCount item(s) to delete:" -ForegroundColor Magenta
        Write-Host ""
        
        $deletedCount = Remove-OrphanedItems -Items $toDelete -Type 'Units' -PSCmdlet $PSCmdlet -ThrottleMs $ThrottleMs
    }
    
    #endregion Phase 2: Delete Orphans
    
    #region Summary
    
    Write-SyncSummary -ImportStats $importStats -DeletedCount $deletedCount -Type "Units" -WhatIf:$WhatIfPreference
    
    $importStats.Deleted = $deletedCount
    return $importStats
    
    #endregion Summary
}
