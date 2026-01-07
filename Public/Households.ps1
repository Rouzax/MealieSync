#Requires -Version 7.0
<#
.SYNOPSIS
    Households function for MealieSync
.DESCRIPTION
    Provides access to Mealie household information.
    Households are used for multi-household Mealie installations
    where foods and tools can be assigned to specific households.
.NOTES
    This is a public function - exported by the module.
#>

function Get-MealieHouseholds {
    <#
    .SYNOPSIS
        Get households from Mealie
    .DESCRIPTION
        Retrieves the list of households from Mealie.
        Results are cached for performance - use -Force to refresh.
    .PARAMETER Force
        Force refresh of cached household data
    .OUTPUTS
        [array] Array of household objects with id, name, slug properties
    .EXAMPLE
        # Get all households
        $households = Get-MealieHouseholds
    .EXAMPLE
        # Force refresh of cache
        $households = Get-MealieHouseholds -Force
    .EXAMPLE
        # Get household names
        (Get-MealieHouseholds).name
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [switch]$Force
    )
    
    # Use the private helper which handles caching
    return Get-ValidHouseholds -Force:$Force
}
