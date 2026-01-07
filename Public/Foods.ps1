#Requires -Version 7.0
<#
.SYNOPSIS
    Foods CRUD functions for MealieSync
.DESCRIPTION
    Provides CRUD operations for Mealie food items (ingredients):
    - Get-MealieFoods: Retrieve foods with pagination
    - New-MealieFood: Create a new food
    - Update-MealieFood: Update an existing food
    - Remove-MealieFood: Delete a food
.NOTES
    These are public functions - exported by the module.
#>

function Get-MealieFoods {
    <#
    .SYNOPSIS
        Get foods from Mealie
    .DESCRIPTION
        Retrieves food items (ingredients) from Mealie with support for pagination.
        Use -All to retrieve all foods across multiple pages.
    .PARAMETER All
        Retrieve all foods (handles pagination automatically)
    .OUTPUTS
        [array] Array of food objects
    .EXAMPLE
        # Get first page of foods
        $foods = Get-MealieFoods
    .EXAMPLE
        # Get all foods
        $allFoods = Get-MealieFoods -All
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [switch]$All
    )
    
    $foods = @()
    $page = 1
    $perPage = 100
    
    do {
        $response = Invoke-MealieRequest -Endpoint "/api/foods?page=$page&perPage=$perPage" -Method 'GET'
        $foods += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $foods
}

function New-MealieFood {
    <#
    .SYNOPSIS
        Create a new food in Mealie
    .DESCRIPTION
        Creates a new food item (ingredient) in Mealie with the specified properties.
    .PARAMETER Name
        The name of the food (required, should be singular Dutch name)
    .PARAMETER PluralName
        The plural form of the name
    .PARAMETER Description
        Description of the food
    .PARAMETER Aliases
        Array of alias names (strings) for the food
    .PARAMETER LabelId
        The UUID of the label to assign to this food
    .OUTPUTS
        [object] The created food object from the API
    .EXAMPLE
        New-MealieFood -Name "tomaat" -PluralName "tomaten" -Description "Rode vruchtgroente"
    .EXAMPLE
        # With label and aliases
        $label = Get-MealieLabels -All | Where-Object { $_.name -eq 'Groente' }
        New-MealieFood -Name "aardappel" -PluralName "aardappelen" -Aliases @("pieper", "piepers") -LabelId $label.id
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [string]$PluralName,
        
        [string]$Description,
        
        [array]$Aliases = @(),
        
        [string]$LabelId
    )
    
    $body = @{
        name = $Name
    }
    
    if (![string]::IsNullOrEmpty($PluralName)) {
        $body.pluralName = $PluralName
    }
    if (![string]::IsNullOrEmpty($Description)) {
        $body.description = $Description
    }
    if (![string]::IsNullOrEmpty($LabelId)) {
        $body.labelId = $LabelId
    }
    if ($Aliases -and $Aliases.Count -gt 0) {
        $body.aliases = @($Aliases | ForEach-Object { @{ name = $_ } })
    }
    
    return Invoke-MealieRequest -Endpoint '/api/foods' -Method 'POST' -Body $body
}

function Update-MealieFood {
    <#
    .SYNOPSIS
        Update an existing food in Mealie
    .DESCRIPTION
        Updates an existing food item with the specified data.
        Only non-null values in the Data hashtable are sent to the API.
    .PARAMETER Id
        The UUID of the food to update
    .PARAMETER Data
        Hashtable containing the fields to update (name, pluralName, description, labelId, aliases)
    .OUTPUTS
        [object] The updated food object from the API
    .EXAMPLE
        Update-MealieFood -Id "abc-123" -Data @{ description = "Nieuwe beschrijving" }
    .EXAMPLE
        # Update multiple fields including aliases
        $data = @{
            name = "tomaat"
            pluralName = "tomaten"
            aliases = @(@{name="tomatje"})
        }
        Update-MealieFood -Id $food.id -Data $data
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
    
    # Build update body - only include non-null values
    $body = @{
        id = $Id
    }
    
    foreach ($key in $Data.Keys) {
        if ($null -ne $Data[$key]) {
            $body[$key] = $Data[$key]
        }
    }
    
    return Invoke-MealieRequest -Endpoint "/api/foods/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieFood {
    <#
    .SYNOPSIS
        Delete a food from Mealie
    .DESCRIPTION
        Permanently deletes a food item from Mealie.
        Warning: This may affect recipes that use this food.
    .PARAMETER Id
        The UUID of the food to delete
    .OUTPUTS
        [object] API response
    .EXAMPLE
        Remove-MealieFood -Id "abc-123"
    .EXAMPLE
        # Delete by finding the food first
        $food = Get-MealieFoods -All | Where-Object { $_.name -eq 'test' }
        Remove-MealieFood -Id $food.id
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/foods/$Id" -Method 'DELETE'
}
