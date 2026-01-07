#Requires -Version 7.0
<#
.SYNOPSIS
    Progress and output helper functions for MealieSync
.DESCRIPTION
    Internal helper functions for consistent progress bars, result output,
    and summary statistics during import operations.
.NOTES
    This is a private function file - not exported by the module.
#>

function Write-ImportProgress {
    <#
    .SYNOPSIS
        Display a consistent progress bar for import operations
    .DESCRIPTION
        Wraps Write-Progress with consistent activity naming and percentage calculation.
    .PARAMETER Activity
        The main activity description (e.g., "Importing Foods")
    .PARAMETER Status
        The current status message
    .PARAMETER Current
        Current item number (1-based)
    .PARAMETER Total
        Total number of items
    .PARAMETER ItemName
        Name of the current item being processed
    .EXAMPLE
        Write-ImportProgress -Activity "Importing Foods" -Status "Processing" -Current 5 -Total 100 -ItemName "tomaat"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,
        
        [string]$Status = "Processing",
        
        [Parameter(Mandatory)]
        [int]$Current,
        
        [Parameter(Mandatory)]
        [int]$Total,
        
        [string]$ItemName
    )
    
    $percentComplete = [math]::Min(100, [math]::Round(($Current / $Total) * 100))
    $statusMessage = if ($ItemName) { "$Status $Current of $Total`: $ItemName" } else { "$Status $Current of $Total" }
    
    Write-Progress -Activity $Activity -Status $statusMessage -PercentComplete $percentComplete
}

function Complete-ImportProgress {
    <#
    .SYNOPSIS
        Complete and hide the progress bar
    .PARAMETER Activity
        The activity name (must match the one used in Write-ImportProgress)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity
    )
    
    Write-Progress -Activity $Activity -Completed
}

function Write-ImportResult {
    <#
    .SYNOPSIS
        Display a colored result line for an import operation
    .DESCRIPTION
        Outputs a consistently formatted result line with appropriate coloring
        based on the operation result.
    .PARAMETER Counter
        Item counter for display (e.g., "5/100")
    .PARAMETER Result
        The operation result (Created, Updated, Skipped, Unchanged, Error, Conflict)
    .PARAMETER ItemName
        Name of the item
    .PARAMETER Details
        Additional details (e.g., match method)
    .PARAMETER Changes
        Array of change objects for update operations
    .EXAMPLE
        Write-ImportResult -Counter "5/100" -Result "Created" -ItemName "tomaat"
    .EXAMPLE
        Write-ImportResult -Counter "10/100" -Result "Updated" -ItemName "aardappel" -Details "(matched by alias)"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Counter,
        
        [Parameter(Mandatory)]
        [ValidateSet('Created', 'Updated', 'Skipped', 'Unchanged', 'Error', 'Conflict', 'Deleted', 'WouldCreate', 'WouldUpdate', 'WouldDelete')]
        [string]$Result,
        
        [Parameter(Mandatory)]
        [string]$ItemName,
        
        [string]$Details,
        
        [array]$Changes
    )
    
    # Determine color based on result
    $color = switch ($Result) {
        'Created'     { 'Green' }
        'WouldCreate' { 'Green' }
        'Updated'     { 'Yellow' }
        'WouldUpdate' { 'Yellow' }
        'Skipped'     { 'DarkGray' }
        'Unchanged'   { 'DarkGray' }
        'Error'       { 'Red' }
        'Conflict'    { 'Red' }
        'Deleted'     { 'Magenta' }
        'WouldDelete' { 'Magenta' }
        default       { 'White' }
    }
    
    # Format the result text
    $resultText = switch ($Result) {
        'WouldCreate' { 'Would CREATE' }
        'WouldUpdate' { 'Would UPDATE' }
        'WouldDelete' { 'Would DELETE' }
        default       { $Result }
    }
    
    # Build output line
    Write-Host "  $Counter " -NoNewline
    Write-Host "$resultText" -ForegroundColor $color -NoNewline
    
    if ($Details) {
        Write-Host " $Details" -NoNewline
    }
    
    Write-Host ": " -NoNewline
    Write-Host "$ItemName" -ForegroundColor Cyan
    
    # Show changes for update operations
    if ($Changes -and $Changes.Count -gt 0) {
        foreach ($change in $Changes) {
            $oldVal = if ([string]::IsNullOrEmpty($change.Old)) { "(empty)" } else { $change.Old }
            $newVal = if ([string]::IsNullOrEmpty($change.New)) { "(empty)" } else { $change.New }
            Write-Host "          $($change.Field.PadRight(12)): " -NoNewline
            Write-Host "'$oldVal'" -ForegroundColor DarkGray -NoNewline
            Write-Host " -> " -NoNewline
            Write-Host "'$newVal'" -ForegroundColor Green
        }
    }
}

function Write-ImportSummary {
    <#
    .SYNOPSIS
        Display a summary of import operation results
    .DESCRIPTION
        Shows a formatted summary table of all operation counts.
    .PARAMETER Stats
        Hashtable with counts for Created, Updated, Skipped, Unchanged, Errors, Conflicts
    .PARAMETER Type
        The type of items imported (Foods, Units, Labels, etc.)
    .PARAMETER WhatIf
        Whether this was a WhatIf run
    .EXAMPLE
        $stats = @{ Created = 5; Updated = 10; Skipped = 0; Unchanged = 85; Errors = 0; Conflicts = 0 }
        Write-ImportSummary -Stats $stats -Type "Foods"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Stats,
        
        [Parameter(Mandatory)]
        [string]$Type,
        
        [switch]$WhatIf
    )
    
    $mode = if ($WhatIf) { " (WhatIf)" } else { "" }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Type Import Summary$mode" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    
    # Calculate total processed
    $total = 0
    $statsList = @('Created', 'Updated', 'Skipped', 'Unchanged', 'Errors', 'Conflicts', 'Deleted', 'LabelWarnings')
    
    foreach ($stat in $statsList) {
        if ($Stats.ContainsKey($stat)) {
            $total += $Stats[$stat]
        }
    }
    
    # Display each stat with appropriate color
    $displayStats = @(
        @{ Name = 'Created'; Color = 'Green' }
        @{ Name = 'Updated'; Color = 'Yellow' }
        @{ Name = 'Unchanged'; Color = 'DarkGray' }
        @{ Name = 'Skipped'; Color = 'DarkGray' }
        @{ Name = 'Deleted'; Color = 'Magenta' }
        @{ Name = 'Errors'; Color = 'Red' }
        @{ Name = 'Conflicts'; Color = 'Red' }
        @{ Name = 'LabelWarnings'; Color = 'DarkYellow' }
    )
    
    foreach ($stat in $displayStats) {
        if ($Stats.ContainsKey($stat.Name) -and $Stats[$stat.Name] -gt 0) {
            $label = $stat.Name.PadRight(15)
            Write-Host "  $label : " -NoNewline
            Write-Host "$($Stats[$stat.Name])" -ForegroundColor $stat.Color
        }
    }
    
    Write-Host "───────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Total processed : $total" -ForegroundColor White
    Write-Host ""
}

function New-ImportStats {
    <#
    .SYNOPSIS
        Create a new stats hashtable for import operations
    .DESCRIPTION
        Returns a hashtable with all standard stat counters initialized to 0.
    .OUTPUTS
        [hashtable] Stats object with Created, Updated, Skipped, Unchanged, Errors, Conflicts, Deleted, LabelWarnings
    .EXAMPLE
        $stats = New-ImportStats
        $stats.Created++
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    return @{
        Created       = 0
        Updated       = 0
        Skipped       = 0
        Unchanged     = 0
        Errors        = 0
        Conflicts     = 0
        Deleted       = 0
        LabelWarnings = 0
    }
}

function Format-ChangeList {
    <#
    .SYNOPSIS
        Build a list of changes between existing and new items
    .DESCRIPTION
        Compares two objects and returns an array of change objects
        for display purposes.
    .PARAMETER Existing
        The existing item from the API
    .PARAMETER New
        The new item from import data
    .PARAMETER Fields
        Array of field names to compare
    .OUTPUTS
        [array] Array of @{ Field; Old; New } change objects
    .EXAMPLE
        $changes = Format-ChangeList -Existing $existingFood -New $newFood -Fields @('name', 'description')
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New,
        
        [Parameter(Mandatory)]
        [array]$Fields
    )
    
    $changes = @()
    
    foreach ($field in $Fields) {
        $existingVal = $Existing.$field
        $newVal = $New.$field
        
        # Skip if both are null/empty
        if ([string]::IsNullOrEmpty($existingVal) -and [string]::IsNullOrEmpty($newVal)) {
            continue
        }
        
        # Check if changed
        if (-not (Compare-StringValue $existingVal $newVal)) {
            # Truncate long values
            $oldDisplay = if ([string]::IsNullOrEmpty($existingVal)) { "" } 
                         elseif ($existingVal.Length -gt 40) { $existingVal.Substring(0, 40) + "..." }
                         else { $existingVal }
            
            $newDisplay = if ([string]::IsNullOrEmpty($newVal)) { "" }
                         elseif ($newVal.Length -gt 40) { $newVal.Substring(0, 40) + "..." }
                         else { $newVal }
            
            $changes += @{
                Field = $field
                Old   = $oldDisplay
                New   = $newDisplay
            }
        }
    }
    
    return $changes
}

function Format-Counter {
    <#
    .SYNOPSIS
        Format a counter string for display
    .PARAMETER Current
        Current item number (1-based)
    .PARAMETER Total
        Total number of items
    .OUTPUTS
        [string] Formatted counter (e.g., "  5/100")
    .EXAMPLE
        $counter = Format-Counter -Current 5 -Total 100
        # Returns "  5/100"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [int]$Current,
        
        [Parameter(Mandatory)]
        [int]$Total
    )
    
    $width = $Total.ToString().Length
    return "$($Current.ToString().PadLeft($width))/$Total"
}

function Show-RecipeUsageWarning {
    <#
    .SYNOPSIS
        Display warning about food items that are used in recipes
    .DESCRIPTION
        Shows a formatted warning message listing foods that cannot be deleted
        because they are linked to recipes. Also shows items that are safe to delete.
    .PARAMETER UsageResult
        The result from Test-FoodsInUse containing UsedItems and SafeToDelete arrays
    .EXAMPLE
        $usage = Test-FoodsInUse -Foods $toDelete
        if ($usage.HasUsedItems) {
            Show-RecipeUsageWarning -UsageResult $usage
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$UsageResult
    )
    
    Write-Host ""
    Write-Host "  ⚠️  Cannot delete items that are used in recipes:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($item in $UsageResult.UsedItems) {
        $recipeText = if ($item.RecipeCount -eq 1) { "1 recipe" } else { "$($item.RecipeCount) recipes" }
        Write-Host "      • " -ForegroundColor Yellow -NoNewline
        Write-Host "$($item.Name)" -ForegroundColor Cyan -NoNewline
        Write-Host " (used in $recipeText)" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "      Remove these items from recipes first, or add them to" -ForegroundColor DarkGray
    Write-Host "      your JSON file to keep them in Mealie." -ForegroundColor DarkGray
    
    if ($UsageResult.SafeToDelete.Count -gt 0) {
        Write-Host ""
        Write-Host "  Items safe to delete: $($UsageResult.SafeToDelete.Count)" -ForegroundColor Green
        foreach ($item in $UsageResult.SafeToDelete) {
            Write-Host "      • " -ForegroundColor Green -NoNewline
            Write-Host "$($item.Name)" -ForegroundColor Cyan -NoNewline
            Write-Host " (not used)" -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
}
