#Requires -Version 7.0
<#
.SYNOPSIS
    Sync (mirror) organizers (categories, tags, tools) in Mealie to match JSON exactly
.DESCRIPTION
    Synchronizes Mealie organizers to exactly match the contents of a JSON file.
    This includes adding new items, updating existing items, AND deleting
    items that exist in Mealie but not in the JSON file.
    
    WARNING: This operation is destructive - it will DELETE items from Mealie
    that are not present in the import file.
.NOTES
    Part of MealieSync module - see README.md for usage examples.
#>

function Sync-MealieOrganizers {
    <#
    .SYNOPSIS
        Sync categories, tags, or tools to exactly match a JSON file
    .DESCRIPTION
        Performs a full synchronization of Mealie organizers to match the JSON file:
        1. Creates new items that exist in JSON but not in Mealie
        2. Updates existing items that have changes
        3. DELETES items that exist in Mealie but not in the JSON file
        
        WARNING: Deleting categories/tags removes them from all recipes that use them.
        
        This is a destructive operation. Use -WhatIf to preview changes safely.
    .PARAMETER Path
        Path to the JSON file containing organizer data
    .PARAMETER Type
        Type of organizer: Categories, Tags, or Tools
    .PARAMETER SkipBackup
        Skip the automatic backup before sync
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER Force
        Skip confirmation prompt for deletions
    .EXAMPLE
        Sync-MealieOrganizers -Path ".\Categories.json" -Type Categories -WhatIf
        # Preview what would be added, updated, and DELETED
    .OUTPUTS
        [hashtable] Statistics with Created, Updated, Unchanged, Skipped, Errors, Deleted
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [ValidateSet('Categories', 'Tags', 'Tools')]
        [string]$Type,
        
        [switch]$SkipBackup,
        
        [int]$ThrottleMs = 100,
        
        [switch]$Force,
        
        [string]$BasePath = "."
    )
    
    if ($Force) {
        $ConfirmPreference = 'None'
    }
    
    # Type-specific warnings
    $warningText = switch ($Type) {
        'Categories' { "Deleting categories removes them from all recipes!" }
        'Tags' { "Deleting tags removes them from all recipes!" }
        'Tools' { "Deleting tools removes them from all recipes!" }
    }
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  " -ForegroundColor Cyan -NoNewline
    Write-Host ("SYNC MODE - This will ADD, UPDATE, and DELETE $Type".PadRight(61)) -ForegroundColor Cyan -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "║  " -ForegroundColor Cyan -NoNewline
    Write-Host ("WARNING: $warningText".PadRight(61)) -ForegroundColor Yellow -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    #region Read and Validate
    
    # For Tools, validate households
    $validateHouseholds = ($Type -eq 'Tools')
    $importResult = Read-ImportFile -Path $Path -ExpectedType $Type -ValidateHouseholds:$validateHouseholds
    
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
        $backupPath = Backup-BeforeImport -Type $Type -BasePath $BasePath
        if ($backupPath) {
            Write-Host "Backup created: $backupPath" -ForegroundColor DarkGray
        }
    }
    
    #endregion Create Backup
    
    #region Phase 1: Import
    
    Write-Host ""
    Write-Host "Phase 1: Importing (add/update)..." -ForegroundColor Cyan
    
    $importStats = Import-MealieOrganizers -Path $Path -Type $Type -UpdateExisting -SkipBackup -ThrottleMs $ThrottleMs
    
    #endregion Phase 1: Import
    
    #region Phase 2: Delete Orphans
    
    Write-Host ""
    Write-Host "Phase 2: Finding orphaned items..." -ForegroundColor Cyan
    
    # Get current items
    $existingItems = switch ($Type) {
        'Categories' { Get-MealieCategories -All }
        'Tags' { Get-MealieTags -All }
        'Tools' { Get-MealieTools -All }
    }
    
    # Organizers match by name only
    $toDelete = Get-ItemsToDelete -ExistingItems $existingItems -ImportItems $importData
    
    $deleteCount = @($toDelete).Count
    
    if ($deleteCount -eq 0) {
        Write-Host "  No orphaned items to delete." -ForegroundColor DarkGray
        $deletedCount = 0
    }
    else {
        Write-Host ""
        Write-Host "  Found $deleteCount item(s) to delete:" -ForegroundColor Magenta
        Write-Host ""
        
        $deletedCount = Remove-OrphanedItems -Items $toDelete -Type $Type -PSCmdlet $PSCmdlet -ThrottleMs $ThrottleMs
    }
    
    #endregion Phase 2: Delete Orphans
    
    #region Summary
    
    Write-SyncSummary -ImportStats $importStats -DeletedCount $deletedCount -Type $Type -WhatIf:$WhatIfPreference
    
    $importStats.Deleted = $deletedCount
    return $importStats
    
    #endregion Summary
}

#region Convenience Wrappers

function Sync-MealieCategories {
    <#
    .SYNOPSIS
        Sync categories to exactly match a JSON file (convenience wrapper)
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER SkipBackup
        Skip the automatic backup before sync
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER Force
        Skip confirmation prompt for deletions
    .PARAMETER BasePath
        Base path for backup files (default: current directory)
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
    
    Sync-MealieOrganizers -Path $Path -Type 'Categories' -SkipBackup:$SkipBackup -ThrottleMs $ThrottleMs -Force:$Force -BasePath $BasePath
}

function Sync-MealieTags {
    <#
    .SYNOPSIS
        Sync tags to exactly match a JSON file (convenience wrapper)
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER SkipBackup
        Skip the automatic backup before sync
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER Force
        Skip confirmation prompt for deletions
    .PARAMETER BasePath
        Base path for backup files (default: current directory)
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
    
    Sync-MealieOrganizers -Path $Path -Type 'Tags' -SkipBackup:$SkipBackup -ThrottleMs $ThrottleMs -Force:$Force -BasePath $BasePath
}

function Sync-MealieTools {
    <#
    .SYNOPSIS
        Sync tools to exactly match a JSON file (convenience wrapper)
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER SkipBackup
        Skip the automatic backup before sync
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER Force
        Skip confirmation prompt for deletions
    .PARAMETER BasePath
        Base path for backup files (default: current directory)
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
    
    Sync-MealieOrganizers -Path $Path -Type 'Tools' -SkipBackup:$SkipBackup -ThrottleMs $ThrottleMs -Force:$Force -BasePath $BasePath
}

#endregion Convenience Wrappers
