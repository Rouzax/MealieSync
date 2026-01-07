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
    .OUTPUTS
        [hashtable] Statistics with Created, Updated, Unchanged, Skipped, Errors, Conflicts, Deleted
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$ReplaceAliases,
        
        [switch]$SkipBackup,
        
        [int]$ThrottleMs = 100,
        
        [switch]$Force,
        
        [string]$BasePath = "."
    )
    
    if ($Force) {
        $ConfirmPreference = 'None'
    }
    
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
