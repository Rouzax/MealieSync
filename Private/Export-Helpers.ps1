#Requires -Version 7.0
<#
.SYNOPSIS
    Export helper functions for MealieSync
.DESCRIPTION
    Internal helper functions for creating export files with the new JSON format,
    handling directory creation, ShouldProcess support, and UTF-8 encoding.
.NOTES
    This is a private function file - not exported by the module.
#>

function New-ExportWrapper {
    <#
    .SYNOPSIS
        Create a JSON wrapper object with schema metadata
    .DESCRIPTION
        Creates the standard MealieSync JSON wrapper structure with
        $schema, $type, $version, and items properties.
    .PARAMETER Type
        The data type (Foods, Units, Labels, Categories, Tags, Tools)
    .PARAMETER Items
        Array of items to include in the wrapper
    .PARAMETER Version
        Schema version (default: "1.0")
    .OUTPUTS
        [PSCustomObject] Wrapper object ready for JSON serialization
    .EXAMPLE
        $wrapper = New-ExportWrapper -Type 'Foods' -Items $foods
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools')]
        [string]$Type,
        
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Items,
        
        [string]$Version = "1.0"
    )
    
    # Use ordered hashtable to ensure consistent property order
    $wrapper = [ordered]@{
        '$schema'  = 'mealie-sync'
        '$type'    = $Type
        '$version' = $Version
        'items'    = $Items
    }
    
    return [PSCustomObject]$wrapper
}

function Write-ExportFile {
    <#
    .SYNOPSIS
        Write export data to a JSON file
    .DESCRIPTION
        Handles directory creation, ShouldProcess confirmation, and UTF-8 encoding
        for export file writing.
    .PARAMETER Path
        Output file path
    .PARAMETER Data
        Data object to serialize to JSON
    .PARAMETER PSCmdlet
        The calling cmdlet's $PSCmdlet for ShouldProcess support
    .OUTPUTS
        [bool] True if file was written, False if skipped (WhatIf)
    .EXAMPLE
        Write-ExportFile -Path ".\Foods.json" -Data $wrapper -PSCmdlet $PSCmdlet
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [object]$Data,
        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$PSCmdlet
    )
    
    # Ensure parent directory exists
    $parentDir = Split-Path -Parent $Path
    if ($parentDir -and -not (Test-Path $parentDir)) {
        if ($PSCmdlet.ShouldProcess($parentDir, "Create directory")) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
    }
    
    # Write file with ShouldProcess support
    if ($PSCmdlet.ShouldProcess($Path, "Export to JSON file")) {
        $json = $Data | ConvertTo-Json -Depth 10
        # Use .NET method for explicit UTF-8 without BOM
        [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
        return $true
    }
    
    return $false
}

function Remove-RedundantAliases {
    <#
    .SYNOPSIS
        Filter out aliases that match name or pluralName
    .DESCRIPTION
        Removes aliases that are redundant because they exactly match the item's
        name or pluralName (case-insensitive but diacritic-sensitive comparison).
        Uses ordinal comparison to preserve diacritic differences.
    .PARAMETER Aliases
        Array of alias objects or alias name strings
    .PARAMETER Name
        The item's primary name
    .PARAMETER PluralName
        The item's plural name
    .OUTPUTS
        [array] Filtered array of aliases (same format as input)
    .EXAMPLE
        $filtered = Remove-RedundantAliases -Aliases $item.aliases -Name "tomaat" -PluralName "tomaten"
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [AllowNull()]
        [array]$Aliases,
        
        [string]$Name,
        
        [string]$PluralName
    )
    
    if (-not $Aliases -or $Aliases.Count -eq 0) {
        return @()
    }
    
    $nameLower = if ($Name) { $Name.ToLower().Trim() } else { "" }
    $pluralLower = if ($PluralName) { $PluralName.ToLower().Trim() } else { "" }
    
    $filtered = @()
    foreach ($alias in $Aliases) {
        # Handle both object format { name = "x" } and string format "x"
        $aliasName = if ($alias -is [string]) { $alias } else { $alias.name }
        $aliasLower = $aliasName.ToLower().Trim()
        
        # Skip if alias exactly matches name or pluralName (ordinal comparison preserves diacritics)
        if ([string]::Equals($aliasLower, $nameLower, [StringComparison]::Ordinal) -or 
            [string]::Equals($aliasLower, $pluralLower, [StringComparison]::Ordinal)) {
            continue
        }
        
        $filtered += $alias
    }
    
    return $filtered
}

function ConvertTo-FoodExport {
    <#
    .SYNOPSIS
        Transform a food object for export
    .DESCRIPTION
        Converts a food object from the API to the clean export format,
        including only the fields needed for import.
        Filters out aliases that match name or pluralName.
    .PARAMETER Food
        The food object from the API
    .OUTPUTS
        [PSCustomObject] Cleaned food object for export
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object]$Food
    )
    
    # Property order: id, name, pluralName, description, aliases, label, households
    $result = [ordered]@{
        id          = $Food.id
        name        = $Food.name
        pluralName  = $Food.pluralName
        description = $Food.description
    }
    
    # Include aliases as simplified objects, filtering out redundant ones
    if ($Food.aliases -and $Food.aliases.Count -gt 0) {
        $filteredAliases = Remove-RedundantAliases -Aliases $Food.aliases -Name $Food.name -PluralName $Food.pluralName
        $result.aliases = @($filteredAliases | ForEach-Object { @{ name = $_.name } })
    }
    else {
        $result.aliases = @()
    }
    
    # Include label name (not labelId) for human-readable export
    if ($Food.label -and $Food.label.name) {
        $result.label = $Food.label.name
    }
    
    # Include households if present
    if ($Food.householdsWithIngredientFood -and $Food.householdsWithIngredientFood.Count -gt 0) {
        $result.householdsWithIngredientFood = @($Food.householdsWithIngredientFood)
    }
    
    return [PSCustomObject]$result
}

function ConvertTo-UnitExport {
    <#
    .SYNOPSIS
        Transform a unit object for export
    .DESCRIPTION
        Converts a unit object from the API to the clean export format.
        Filters out aliases that match name or pluralName.
    .PARAMETER Unit
        The unit object from the API
    .OUTPUTS
        [PSCustomObject] Cleaned unit object for export
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object]$Unit
    )
    
    $result = [ordered]@{
        id                 = $Unit.id
        name               = $Unit.name
        pluralName         = $Unit.pluralName
        description        = $Unit.description
        abbreviation       = $Unit.abbreviation
        pluralAbbreviation = $Unit.pluralAbbreviation
        useAbbreviation    = $Unit.useAbbreviation
        fraction           = $Unit.fraction
    }
    
    # Include aliases as simplified objects, filtering out redundant ones
    if ($Unit.aliases -and $Unit.aliases.Count -gt 0) {
        $filteredAliases = Remove-RedundantAliases -Aliases $Unit.aliases -Name $Unit.name -PluralName $Unit.pluralName
        $result.aliases = @($filteredAliases | ForEach-Object { @{ name = $_.name } })
    }
    else {
        $result.aliases = @()
    }
    
    return [PSCustomObject]$result
}

function ConvertTo-LabelExport {
    <#
    .SYNOPSIS
        Transform a label object for export
    .DESCRIPTION
        Converts a label object from the API to the clean export format.
        Omits groupId.
    .PARAMETER Label
        The label object from the API
    .OUTPUTS
        [PSCustomObject] Cleaned label object for export
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object]$Label
    )
    
    return [PSCustomObject][ordered]@{
        id    = $Label.id
        name  = $Label.name
        color = $Label.color
    }
}

function ConvertTo-OrganizerExport {
    <#
    .SYNOPSIS
        Transform an organizer (category/tag/tool) object for export
    .DESCRIPTION
        Converts an organizer object from the API to the clean export format.
        Omits groupId and slug. For tools, includes householdsWithTool.
    .PARAMETER Item
        The organizer object from the API
    .PARAMETER Type
        The organizer type (Categories, Tags, Tools)
    .OUTPUTS
        [PSCustomObject] Cleaned organizer object for export
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object]$Item,
        
        [Parameter(Mandatory)]
        [ValidateSet('Categories', 'Tags', 'Tools')]
        [string]$Type
    )
    
    $result = [ordered]@{
        id   = $Item.id
        name = $Item.name
    }
    
    # Tools have householdsWithTool
    if ($Type -eq 'Tools' -and $Item.householdsWithTool -and $Item.householdsWithTool.Count -gt 0) {
        $result.householdsWithTool = @($Item.householdsWithTool)
    }
    
    return [PSCustomObject]$result
}
