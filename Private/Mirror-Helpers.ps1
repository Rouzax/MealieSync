#Requires -Version 7.0
<#
.SYNOPSIS
    Mirror/Sync helper functions for MealieSync
.DESCRIPTION
    Internal helper functions for finding items to delete during mirror/sync
    operations. Mirror syncs Mealie to exactly match a JSON file by
    adding, updating, AND deleting items.
.NOTES
    This is a private function file - not exported by the module.
#>

function Get-ItemsToDelete {
    <#
    .SYNOPSIS
        Find items that exist in Mealie but not in import data
    .DESCRIPTION
        Compares existing items from the API against import data to find
        "orphans" - items that should be deleted during a mirror/sync operation.
        
        For Foods and Units: matches by id (primary) or name (fallback)
        For Labels/Categories/Tags/Tools: matches by name only
    .PARAMETER ExistingItems
        Array of items currently in Mealie (from Get-Mealie* functions)
    .PARAMETER ImportItems
        Array of items from the import JSON file
    .PARAMETER MatchById
        If true, match by id first, then name. If false, match by name only.
    .OUTPUTS
        [array] Items from ExistingItems that are not in ImportItems
    .EXAMPLE
        $toDelete = Get-ItemsToDelete -ExistingItems $existingFoods -ImportItems $importFoods -MatchById
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [array]$ExistingItems,
        
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [array]$ImportItems,
        
        [switch]$MatchById
    )
    
    # Handle null inputs
    if ($null -eq $ExistingItems) { $ExistingItems = @() }
    if ($null -eq $ImportItems) { $ImportItems = @() }
    
    # Build lookup sets for import items
    $importIds = @{}
    $importNames = @{}
    
    foreach ($item in $ImportItems) {
        # Track by id if present
        if ($MatchById -and ![string]::IsNullOrEmpty($item.id)) {
            $importIds[$item.id] = $true
        }
        
        # Track by name (always, as fallback)
        if (![string]::IsNullOrEmpty($item.name)) {
            $importNames[$item.name.ToLower().Trim()] = $true
        }
        
        # Also track by pluralName for foods/units
        if (![string]::IsNullOrEmpty($item.pluralName)) {
            $importNames[$item.pluralName.ToLower().Trim()] = $true
        }
    }
    
    # Find items in existing that are NOT in import
    $toDelete = @()
    
    foreach ($existing in $ExistingItems) {
        $found = $false
        
        # Check by id first (if matching by id)
        if ($MatchById -and ![string]::IsNullOrEmpty($existing.id)) {
            if ($importIds.ContainsKey($existing.id)) {
                $found = $true
            }
        }
        
        # Check by name (fallback or primary for simple types)
        if (-not $found -and ![string]::IsNullOrEmpty($existing.name)) {
            $nameKey = $existing.name.ToLower().Trim()
            if ($importNames.ContainsKey($nameKey)) {
                $found = $true
            }
        }
        
        # Check by pluralName (for foods/units that might have been renamed)
        if (-not $found -and ![string]::IsNullOrEmpty($existing.pluralName)) {
            $pluralKey = $existing.pluralName.ToLower().Trim()
            if ($importNames.ContainsKey($pluralKey)) {
                $found = $true
            }
        }
        
        if (-not $found) {
            $toDelete += $existing
        }
    }
    
    return $toDelete
}

function Remove-OrphanedItems {
    <#
    .SYNOPSIS
        Delete orphaned items from Mealie
    .DESCRIPTION
        Deletes items that exist in Mealie but not in the import data.
        Supports -WhatIf and -Confirm for safe operation.
    .PARAMETER Items
        Array of items to delete
    .PARAMETER Type
        Type of items (Foods, Units, Labels, Categories, Tags, Tools)
    .PARAMETER PSCmdlet
        The calling cmdlet's $PSCmdlet for ShouldProcess support
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls
    .OUTPUTS
        [int] Number of items deleted
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Items,
        
        [Parameter(Mandatory)]
        [ValidateSet('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools')]
        [string]$Type,
        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$PSCmdlet,
        
        [int]$ThrottleMs = 100
    )
    
    $deleted = 0
    $total = @($Items).Count
    $current = 0
    
    foreach ($item in $Items) {
        $current++
        $counter = Format-Counter -Current $current -Total $total
        $itemName = $item.name
        
        # Use WhatIf-aware output
        if ($PSCmdlet.ShouldProcess($itemName, "Delete $Type")) {
            try {
                switch ($Type) {
                    'Foods' { Remove-MealieFood -Id $item.id | Out-Null }
                    'Units' { Remove-MealieUnit -Id $item.id | Out-Null }
                    'Labels' { Remove-MealieLabel -Id $item.id | Out-Null }
                    'Categories' { Remove-MealieCategory -Id $item.id | Out-Null }
                    'Tags' { Remove-MealieTag -Id $item.id | Out-Null }
                    'Tools' { Remove-MealieTool -Id $item.id | Out-Null }
                }
                
                Write-ImportResult -Counter $counter -Result 'Deleted' -ItemName $itemName
                $deleted++
                
                if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
            }
            catch {
                Write-Warning "  $counter Error deleting '$itemName': $_"
            }
        }
        else {
            # WhatIf mode
            Write-ImportResult -Counter $counter -Result 'WouldDelete' -ItemName $itemName
            $deleted++
        }
    }
    
    return $deleted
}

function Show-MirrorPreview {
    <#
    .SYNOPSIS
        Display a preview summary of mirror operation
    .DESCRIPTION
        Shows a formatted summary of pending changes before execution,
        including import stats and items to be deleted.
    .PARAMETER ImportPreview
        Hashtable with import preview stats (from dry-run)
    .PARAMETER DeleteItems
        Array of items that would be deleted
    .PARAMETER Type
        Data type (Foods, Units, etc.)
    .PARAMETER Label
        Label scope if specified
    .PARAMETER BackupPath
        Path to backup file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ImportPreview,
        
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$DeleteItems,
        
        [Parameter(Mandatory)]
        [string]$Type,
        
        [string]$Label,
        
        [string]$BackupPath
    )
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " Mirror Preview - $Type" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Phase 1 - Import:" -ForegroundColor White
    Write-Host "   Create  : $($ImportPreview.Created)" -ForegroundColor Green
    Write-Host "   Update  : $($ImportPreview.Updated)" -ForegroundColor Yellow
    
    $skipCount = ($ImportPreview.Unchanged + $ImportPreview.Skipped)
    Write-Host "   Skip    : $skipCount" -ForegroundColor DarkGray
    
    if ($ImportPreview.Errors -gt 0) {
        Write-Host "   Errors  : $($ImportPreview.Errors)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host " Phase 2 - Delete:" -ForegroundColor White
    
    $deleteCount = @($DeleteItems).Count
    if ($deleteCount -gt 0) {
        if ($Label) {
            Write-Host "   Delete  : $deleteCount item(s) with label '$Label'" -ForegroundColor Red
        }
        else {
            Write-Host "   Delete  : $deleteCount item(s)" -ForegroundColor Red
        }
        
        # Show first few items to delete
        $showCount = [Math]::Min(5, $deleteCount)
        Write-Host ""
        Write-Host "   Items to delete:" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $showCount; $i++) {
            Write-Host "     - $($DeleteItems[$i].name)" -ForegroundColor DarkGray
        }
        if ($deleteCount -gt 5) {
            Write-Host "     ... and $($deleteCount - 5) more" -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host "   Delete  : 0 items" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    if ($BackupPath) {
        Write-Host " Backup: $BackupPath" -ForegroundColor DarkGray
    }
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Request-MirrorConfirmation {
    <#
    .SYNOPSIS
        Prompt user for confirmation to proceed with mirror
    .DESCRIPTION
        Displays a warning about deletions and prompts for Y/N confirmation.
    .PARAMETER DeleteCount
        Number of items to be deleted
    .PARAMETER CreateCount
        Number of items to be created
    .PARAMETER UpdateCount
        Number of items to be updated
    .OUTPUTS
        [bool] True if user confirms, False otherwise
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [int]$DeleteCount = 0,
        [int]$CreateCount = 0,
        [int]$UpdateCount = 0
    )
    
    $totalChanges = $CreateCount + $UpdateCount + $DeleteCount
    
    if ($totalChanges -eq 0) {
        Write-Host "No changes to make." -ForegroundColor DarkGray
        return $false
    }
    
    if ($DeleteCount -gt 0) {
        Write-Host "WARNING: This will DELETE $DeleteCount item(s) from Mealie." -ForegroundColor Red
    }
    
    Write-Host ""
    $response = Read-Host "Continue with $totalChanges change(s)? [Y/N]"
    return ($response -eq 'Y' -or $response -eq 'y')
}

function Write-SyncSummary {
    <#
    .SYNOPSIS
        Display a summary of sync operation results
    .DESCRIPTION
        Shows a formatted summary including import stats plus deletion count.
    .PARAMETER ImportStats
        Hashtable with import statistics (Created, Updated, etc.)
    .PARAMETER DeletedCount
        Number of items deleted
    .PARAMETER Type
        The type of items synced
    .PARAMETER WhatIf
        Whether this was a WhatIf run
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ImportStats,
        
        [Parameter(Mandatory)]
        [int]$DeletedCount,
        
        [Parameter(Mandatory)]
        [string]$Type,
        
        [switch]$WhatIf
    )
    
    # Add deleted count to stats
    $stats = $ImportStats.Clone()
    $stats.Deleted = $DeletedCount
    
    # Use existing Write-ImportSummary with the combined stats
    Write-ImportSummary -Stats $stats -Type $Type -WhatIf:$WhatIf
}
