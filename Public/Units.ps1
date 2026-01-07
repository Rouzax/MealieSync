#Requires -Version 7.0
<#
.SYNOPSIS
    Units CRUD functions for MealieSync
.DESCRIPTION
    Provides CRUD operations for Mealie measurement units:
    - Get-MealieUnits: Retrieve units with pagination
    - New-MealieUnit: Create a new unit
    - Update-MealieUnit: Update an existing unit
    - Remove-MealieUnit: Delete a unit
.NOTES
    These are public functions - exported by the module.
#>

function Get-MealieUnits {
    <#
    .SYNOPSIS
        Get units from Mealie
    .DESCRIPTION
        Retrieves measurement units from Mealie with support for pagination.
        Use -All to retrieve all units across multiple pages.
    .PARAMETER All
        Retrieve all units (handles pagination automatically)
    .OUTPUTS
        [array] Array of unit objects
    .EXAMPLE
        # Get first page of units
        $units = Get-MealieUnits
    .EXAMPLE
        # Get all units
        $allUnits = Get-MealieUnits -All
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [switch]$All
    )
    
    $units = @()
    $page = 1
    $perPage = 100
    
    do {
        $response = Invoke-MealieRequest -Endpoint "/api/units?page=$page&perPage=$perPage" -Method 'GET'
        $units += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $units
}

function New-MealieUnit {
    <#
    .SYNOPSIS
        Create a new unit in Mealie
    .DESCRIPTION
        Creates a new measurement unit in Mealie with the specified properties.
    .PARAMETER Name
        The name of the unit (required)
    .PARAMETER PluralName
        The plural form of the name
    .PARAMETER Description
        Description of the unit
    .PARAMETER Abbreviation
        Abbreviation for the unit (e.g., "g" for gram)
    .PARAMETER PluralAbbreviation
        Plural form of the abbreviation (often same as singular)
    .PARAMETER UseAbbreviation
        Whether to display the abbreviation instead of full name (default: false)
    .PARAMETER Fraction
        Whether to display as fraction (e.g., 1/2) instead of decimal (default: true)
    .PARAMETER Aliases
        Array of alias names (strings) for the unit
    .OUTPUTS
        [object] The created unit object from the API
    .EXAMPLE
        New-MealieUnit -Name "gram" -PluralName "gram" -Abbreviation "g" -UseAbbreviation $true
    .EXAMPLE
        # With description and aliases
        New-MealieUnit -Name "eetlepel" -PluralName "eetlepels" -Abbreviation "el" -Aliases @("tbsp", "tablespoon")
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [string]$PluralName,
        
        [string]$Description,
        
        [string]$Abbreviation,
        
        [string]$PluralAbbreviation,
        
        [bool]$UseAbbreviation = $false,
        
        [bool]$Fraction = $true,
        
        [array]$Aliases = @()
    )
    
    $body = @{
        name            = $Name
        useAbbreviation = $UseAbbreviation
        fraction        = $Fraction
    }
    
    if (![string]::IsNullOrEmpty($PluralName)) {
        $body.pluralName = $PluralName
    }
    if (![string]::IsNullOrEmpty($Description)) {
        $body.description = $Description
    }
    if (![string]::IsNullOrEmpty($Abbreviation)) {
        $body.abbreviation = $Abbreviation
    }
    if (![string]::IsNullOrEmpty($PluralAbbreviation)) {
        $body.pluralAbbreviation = $PluralAbbreviation
    }
    if ($Aliases -and $Aliases.Count -gt 0) {
        $body.aliases = @($Aliases | ForEach-Object { @{ name = $_ } })
    }
    
    return Invoke-MealieRequest -Endpoint '/api/units' -Method 'POST' -Body $body
}

function Update-MealieUnit {
    <#
    .SYNOPSIS
        Update an existing unit in Mealie
    .DESCRIPTION
        Updates an existing unit with the specified data.
        Only non-null values in the Data hashtable are sent to the API.
    .PARAMETER Id
        The UUID of the unit to update
    .PARAMETER Data
        Hashtable containing the fields to update
    .OUTPUTS
        [object] The updated unit object from the API
    .EXAMPLE
        Update-MealieUnit -Id "abc-123" -Data @{ abbreviation = "tsp" }
    .EXAMPLE
        # Update multiple fields
        $data = @{
            name = "theelepel"
            abbreviation = "tl"
            useAbbreviation = $true
        }
        Update-MealieUnit -Id $unit.id -Data $data
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [hashtable]$Data
    )
    
    $body = @{
        id = $Id
    }
    
    foreach ($key in $Data.Keys) {
        if ($null -ne $Data[$key]) {
            $body[$key] = $Data[$key]
        }
    }
    
    return Invoke-MealieRequest -Endpoint "/api/units/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieUnit {
    <#
    .SYNOPSIS
        Delete a unit from Mealie
    .DESCRIPTION
        Permanently deletes a unit from Mealie.
        Warning: This may affect recipes that use this unit.
    .PARAMETER Id
        The UUID of the unit to delete
    .OUTPUTS
        [object] API response
    .EXAMPLE
        Remove-MealieUnit -Id "abc-123"
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/units/$Id" -Method 'DELETE'
}
