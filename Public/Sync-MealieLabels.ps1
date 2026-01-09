#Requires -Version 7.0
<#
.SYNOPSIS
    Sync (mirror) labels in Mealie to match a JSON file exactly
.DESCRIPTION
    Synchronizes Mealie labels to exactly match the contents of a JSON file.
    This includes adding new items, updating existing items, AND deleting
    items that exist in Mealie but not in the JSON file.
    
    WARNING: This operation is destructive - it will DELETE labels from Mealie
    that are not present in the import file. Deleting labels will remove them
    from any foods they are assigned to.
.NOTES
    Part of MealieSync module - see README.md for usage examples.
#>

function Sync-MealieLabels {
    <#
    .SYNOPSIS
        Sync labels to exactly match a JSON file (add, update, AND delete)
    .DESCRIPTION
        Performs a full synchronization of Mealie labels to match the JSON file:
        1. Creates new labels that exist in JSON but not in Mealie
        2. Updates existing labels that have changes
        3. DELETES labels that exist in Mealie but not in the JSON file
        
        WARNING: Deleting a label removes it from all foods that use it.
        
        This is a destructive operation. Use -WhatIf to preview changes safely.
    .PARAMETER Path
        Path to the JSON file containing label data
    .PARAMETER SkipBackup
        Skip the automatic backup before sync
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER Force
        Skip confirmation prompt for deletions
    .EXAMPLE
        Sync-MealieLabels -Path ".\Labels.json" -WhatIf
        # Preview what would be added, updated, and DELETED
    .OUTPUTS
        [hashtable] Statistics with Created, Updated, Unchanged, Skipped, Errors, Deleted
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$SkipBackup,
        
        [int]$ThrottleMs = 100,
        
        [switch]$Force,
        
        [string]$BasePath = "."
    )
    
    if ($Force) {
        $ConfirmPreference = 'None'
    }
    
    Write-MirrorHeader -Type 'Labels' -Warning "Deleting labels removes them from all foods!"
    
    #region Read and Validate
    
    $importResult = Read-ImportFile -Path $Path -ExpectedType 'Labels'
    
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
        $backupPath = Backup-BeforeImport -Type 'Labels' -BasePath $BasePath
        if ($backupPath) {
            Write-Host "Backup created: $backupPath" -ForegroundColor DarkGray
        }
    }
    
    #endregion Create Backup
    
    #region Phase 1: Import
    
    Write-Host ""
    Write-Host "Phase 1: Importing (add/update)..." -ForegroundColor Cyan
    
    $importStats = Import-MealieLabels -Path $Path -UpdateExisting -SkipBackup -ThrottleMs $ThrottleMs
    
    #endregion Phase 1: Import
    
    #region Phase 2: Delete Orphans
    
    Write-Host ""
    Write-Host "Phase 2: Finding orphaned items..." -ForegroundColor Cyan
    
    $existingLabels = Get-MealieLabels -All
    # Labels match by name only, not id
    $toDelete = Get-ItemsToDelete -ExistingItems $existingLabels -ImportItems $importData
    
    $deleteCount = @($toDelete).Count
    
    if ($deleteCount -eq 0) {
        Write-Host "  No orphaned items to delete." -ForegroundColor DarkGray
        $deletedCount = 0
    }
    else {
        Write-Host ""
        Write-Host "  Found $deleteCount item(s) to delete:" -ForegroundColor Magenta
        Write-Host ""
        
        $deletedCount = Remove-OrphanedItems -Items $toDelete -Type 'Labels' -PSCmdlet $PSCmdlet -ThrottleMs $ThrottleMs
    }
    
    #endregion Phase 2: Delete Orphans
    
    #region Summary
    
    Write-SyncSummary -ImportStats $importStats -DeletedCount $deletedCount -Type "Labels" -WhatIf:$WhatIfPreference
    
    $importStats.Deleted = $deletedCount
    return $importStats
    
    #endregion Summary
}
