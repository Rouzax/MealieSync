#Requires -Version 7.0
<#
.SYNOPSIS
    Change detection functions for MealieSync
.DESCRIPTION
    Internal helper functions that detect whether items have changed
    compared to existing data. Used to skip unnecessary API calls.
.NOTES
    This is a private function file - not exported by the module.
#>

function Test-FoodChanged {
    <#
    .SYNOPSIS
        Check if a food item has changes compared to existing data
    .DESCRIPTION
        Compares all relevant food fields to detect changes.
        For aliases, compares the merged result against existing aliases.
    .PARAMETER Existing
        The existing food object from the API
    .PARAMETER New
        The new food object from import data
    .PARAMETER ResolvedLabelId
        The resolved labelId from the import data (after name lookup)
    .PARAMETER MergedAliases
        The actual merged alias names that will be written (after filtering)
    .OUTPUTS
        [bool] True if changes detected, False if no changes
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New,
        
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ResolvedLabelId,
        
        [array]$MergedAliases
    )
    
    # Compare name
    if (-not (Compare-StringValue $Existing.name $New.name)) { return $true }
    
    # Compare pluralName
    if (-not (Compare-StringValue $Existing.pluralName $New.pluralName)) { return $true }
    
    # Compare description
    if (-not (Compare-StringValue $Existing.description $New.description)) { return $true }
    
    # Compare labelId (existing labelId vs resolved labelId from import)
    if (-not (Compare-StringValue $Existing.labelId $ResolvedLabelId)) { return $true }
    
    # Compare aliases (existing vs merged result)
    $existingAliasNames = @()
    if ($Existing.aliases -and $Existing.aliases.Count -gt 0) {
        $existingAliasNames = @($Existing.aliases | ForEach-Object { $_.name.ToLower().Trim() }) | Sort-Object
    }
    
    $mergedAliasNamesLower = @()
    if ($MergedAliases -and $MergedAliases.Count -gt 0) {
        $mergedAliasNamesLower = @($MergedAliases | ForEach-Object { $_.ToLower().Trim() }) | Sort-Object
    }
    
    # If merged result differs from existing, there's a change (use ordinal comparison for diacritics)
    $existingStr = $existingAliasNames -join ","
    $mergedStr = $mergedAliasNamesLower -join ","
    if (-not [string]::Equals($existingStr, $mergedStr, [StringComparison]::Ordinal)) { return $true }
    
    return $false
}

function Test-FoodChangedReplace {
    <#
    .SYNOPSIS
        Check if a food item has changes (replacement mode for aliases)
    .DESCRIPTION
        Same as Test-FoodChanged but compares aliases directly (replacement mode)
        instead of merging. Used when -ReplaceAliases switch is active.
        
        Filters redundant aliases (matching name/pluralName) from import data
        before comparison, since Mealie filters these server-side.
    .PARAMETER Existing
        The existing food object from the API
    .PARAMETER New
        The new food object from import data
    .PARAMETER ResolvedLabelId
        The resolved labelId from the import data (after name lookup)
    .OUTPUTS
        [bool] True if changes detected, False if no changes
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New,
        
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ResolvedLabelId
    )
    
    # Compare name
    if (-not (Compare-StringValue $Existing.name $New.name)) { return $true }
    
    # Compare pluralName
    if (-not (Compare-StringValue $Existing.pluralName $New.pluralName)) { return $true }
    
    # Compare description
    if (-not (Compare-StringValue $Existing.description $New.description)) { return $true }
    
    # Compare labelId
    if (-not (Compare-StringValue $Existing.labelId $ResolvedLabelId)) { return $true }
    
    # Filter redundant aliases from import data before comparison
    # (Mealie filters aliases matching name/pluralName server-side)
    $nameLower = if ($New.name) { $New.name.ToLower().Trim() } else { "" }
    $pluralLower = if ($New.pluralName) { $New.pluralName.ToLower().Trim() } else { "" }
    
    $filteredNewAliases = @()
    if ($New.aliases -and $New.aliases.Count -gt 0) {
        foreach ($alias in $New.aliases) {
            $aliasName = if ($alias -is [string]) { $alias } else { $alias.name }
            $aliasLower = $aliasName.ToLower().Trim()
            
            # Skip if alias matches name or pluralName
            if ([string]::Equals($aliasLower, $nameLower, [StringComparison]::Ordinal) -or 
                [string]::Equals($aliasLower, $pluralLower, [StringComparison]::Ordinal)) {
                continue
            }
            
            $filteredNewAliases += $alias
        }
    }
    
    # Compare aliases (existing vs filtered new)
    if (-not (Compare-Aliases $Existing.aliases $filteredNewAliases)) { return $true }
    
    return $false
}

function Test-UnitChanged {
    <#
    .SYNOPSIS
        Check if a unit item has changes compared to existing data
    .DESCRIPTION
        Compares all relevant unit fields including string values,
        booleans, and aliases.
    .PARAMETER Existing
        The existing unit object from the API
    .PARAMETER New
        The new unit object from import data
    .PARAMETER MergedAliases
        Pre-computed merged aliases array (existing + new, deduplicated)
    .OUTPUTS
        [bool] True if changes detected, False if no changes
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New,
        
        [AllowNull()]
        [array]$MergedAliases
    )
    
    # Compare string fields
    if (-not (Compare-StringValue $Existing.name $New.name)) { return $true }
    if (-not (Compare-StringValue $Existing.pluralName $New.pluralName)) { return $true }
    if (-not (Compare-StringValue $Existing.description $New.description)) { return $true }
    if (-not (Compare-StringValue $Existing.abbreviation $New.abbreviation)) { return $true }
    if (-not (Compare-StringValue $Existing.pluralAbbreviation $New.pluralAbbreviation)) { return $true }
    
    # Compare boolean fields with proper defaults
    $existingUseAbbr = if ($null -eq $Existing.useAbbreviation) { $false } else { [bool]$Existing.useAbbreviation }
    $newUseAbbr = if ($null -eq $New.useAbbreviation) { $false } else { [bool]$New.useAbbreviation }
    if ($existingUseAbbr -ne $newUseAbbr) { return $true }
    
    $existingFraction = if ($null -eq $Existing.fraction) { $true } else { [bool]$Existing.fraction }
    $newFraction = if ($null -eq $New.fraction) { $true } else { [bool]$New.fraction }
    if ($existingFraction -ne $newFraction) { return $true }
    
    # Compare aliases using merge logic
    $existingAliasNames = @()
    if ($Existing.aliases -and $Existing.aliases.Count -gt 0) {
        $existingAliasNames = @($Existing.aliases | ForEach-Object { $_.name.ToLower().Trim() }) | Sort-Object
    }
    
    $mergedAliasLower = @()
    if ($MergedAliases -and $MergedAliases.Count -gt 0) {
        $mergedAliasLower = @($MergedAliases | ForEach-Object { $_.ToLower().Trim() }) | Sort-Object
    }
    
    # Use ordinal comparison for diacritics
    $existingStr = $existingAliasNames -join ","
    $mergedStr = $mergedAliasLower -join ","
    if (-not [string]::Equals($existingStr, $mergedStr, [StringComparison]::Ordinal)) { return $true }
    
    return $false
}

function Test-UnitChangedReplace {
    <#
    .SYNOPSIS
        Check if a unit item has changes (replacement mode for aliases)
    .DESCRIPTION
        Same as Test-UnitChanged but compares aliases directly (replacement mode).
        
        Filters redundant aliases (matching name/pluralName) from import data
        before comparison, since Mealie filters these server-side.
    .PARAMETER Existing
        The existing unit object from the API
    .PARAMETER New
        The new unit object from import data
    .OUTPUTS
        [bool] True if changes detected, False if no changes
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New
    )
    
    # Compare string fields
    if (-not (Compare-StringValue $Existing.name $New.name)) { return $true }
    if (-not (Compare-StringValue $Existing.pluralName $New.pluralName)) { return $true }
    if (-not (Compare-StringValue $Existing.description $New.description)) { return $true }
    if (-not (Compare-StringValue $Existing.abbreviation $New.abbreviation)) { return $true }
    if (-not (Compare-StringValue $Existing.pluralAbbreviation $New.pluralAbbreviation)) { return $true }
    
    # Compare boolean fields
    $existingUseAbbr = if ($null -eq $Existing.useAbbreviation) { $false } else { [bool]$Existing.useAbbreviation }
    $newUseAbbr = if ($null -eq $New.useAbbreviation) { $false } else { [bool]$New.useAbbreviation }
    if ($existingUseAbbr -ne $newUseAbbr) { return $true }
    
    $existingFraction = if ($null -eq $Existing.fraction) { $true } else { [bool]$Existing.fraction }
    $newFraction = if ($null -eq $New.fraction) { $true } else { [bool]$New.fraction }
    if ($existingFraction -ne $newFraction) { return $true }
    
    # Filter redundant aliases from import data before comparison
    # (Mealie filters aliases matching name/pluralName server-side)
    $nameLower = if ($New.name) { $New.name.ToLower().Trim() } else { "" }
    $pluralLower = if ($New.pluralName) { $New.pluralName.ToLower().Trim() } else { "" }
    
    $filteredNewAliases = @()
    if ($New.aliases -and $New.aliases.Count -gt 0) {
        foreach ($alias in $New.aliases) {
            $aliasName = if ($alias -is [string]) { $alias } else { $alias.name }
            $aliasLower = $aliasName.ToLower().Trim()
            
            # Skip if alias matches name or pluralName
            if ([string]::Equals($aliasLower, $nameLower, [StringComparison]::Ordinal) -or 
                [string]::Equals($aliasLower, $pluralLower, [StringComparison]::Ordinal)) {
                continue
            }
            
            $filteredNewAliases += $alias
        }
    }
    
    # Compare aliases (existing vs filtered new)
    if (-not (Compare-Aliases $Existing.aliases $filteredNewAliases)) { return $true }
    
    return $false
}

function Test-LabelChanged {
    <#
    .SYNOPSIS
        Check if a label has changes compared to existing data
    .DESCRIPTION
        Compares name and color fields.
    .PARAMETER Existing
        The existing label object from the API
    .PARAMETER New
        The new label object from import data
    .OUTPUTS
        [bool] True if changes detected, False if no changes
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New
    )
    
    if (-not (Compare-StringValue $Existing.name $New.name)) { return $true }
    if (-not (Compare-StringValue $Existing.color $New.color)) { return $true }
    
    return $false
}

function Test-OrganizerChanged {
    <#
    .SYNOPSIS
        Check if a category/tag/tool has changes compared to existing data
    .DESCRIPTION
        For organizers (categories, tags, tools), only the name field matters.
    .PARAMETER Existing
        The existing organizer object from the API
    .PARAMETER New
        The new organizer object from import data
    .OUTPUTS
        [bool] True if changes detected, False if no changes
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New
    )
    
    # Only name matters for organizers
    if (-not (Compare-StringValue $Existing.name $New.name)) { return $true }
    
    return $false
}

function Test-ToolChanged {
    <#
    .SYNOPSIS
        Check if a tool has changes compared to existing data
    .DESCRIPTION
        Compares name and householdsWithTool fields.
    .PARAMETER Existing
        The existing tool object from the API
    .PARAMETER New
        The new tool object from import data
    .OUTPUTS
        [bool] True if changes detected, False if no changes
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New
    )
    
    # Compare name
    if (-not (Compare-StringValue $Existing.name $New.name)) { return $true }
    
    # Compare householdsWithTool (if present)
    if (-not (Compare-HouseholdArray $Existing.householdsWithTool $New.householdsWithTool)) { return $true }
    
    return $false
}