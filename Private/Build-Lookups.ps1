#Requires -Version 7.0
<#
.SYNOPSIS
    Lookup table builder functions for MealieSync
.DESCRIPTION
    Internal helper functions that create hashtable lookups for efficient
    matching during import operations. Supports lookup by id, name, 
    pluralName, and aliases.
.NOTES
    This is a private function file - not exported by the module.
#>

function Build-FoodLookups {
    <#
    .SYNOPSIS
        Build lookup tables for food matching
    .DESCRIPTION
        Creates three hashtables for efficient food matching:
        - ById: id -> food object
        - ByName: name/pluralName (lowercase) -> food object
        - ByAlias: alias name (lowercase) -> food object
    .PARAMETER Foods
        Array of food objects from the API
    .OUTPUTS
        [hashtable] @{ ById = @{}; ByName = @{}; ByAlias = @{} }
    .EXAMPLE
        $foods = Get-MealieFoods -All
        $lookups = Build-FoodLookups -Foods $foods
        $food = $lookups.ByName['tomaat']
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Foods
    )
    
    $lookups = @{
        ById    = @{}
        ByName  = @{}
        ByAlias = @{}
    }
    
    foreach ($food in $Foods) {
        # By ID
        if ($food.id) {
            $lookups.ById[$food.id] = $food
        }
        
        # By name (lowercase)
        if (![string]::IsNullOrEmpty($food.name)) {
            $nameKey = $food.name.ToLower().Trim()
            $lookups.ByName[$nameKey] = $food
        }
        
        # By pluralName (lowercase) - also in ByName lookup
        if (![string]::IsNullOrEmpty($food.pluralName)) {
            $pluralKey = $food.pluralName.ToLower().Trim()
            if (-not $lookups.ByName.ContainsKey($pluralKey)) {
                $lookups.ByName[$pluralKey] = $food
            }
        }
        
        # By alias (lowercase)
        if ($food.aliases -and $food.aliases.Count -gt 0) {
            foreach ($alias in $food.aliases) {
                if (![string]::IsNullOrEmpty($alias.name)) {
                    $aliasKey = $alias.name.ToLower().Trim()
                    if (-not $lookups.ByAlias.ContainsKey($aliasKey)) {
                        $lookups.ByAlias[$aliasKey] = $food
                    }
                }
            }
        }
    }
    
    return $lookups
}

function Build-UnitLookups {
    <#
    .SYNOPSIS
        Build lookup tables for unit matching
    .DESCRIPTION
        Creates three hashtables for efficient unit matching:
        - ById: id -> unit object
        - ByName: name/pluralName/abbreviation (lowercase) -> unit object
        - ByAlias: alias name (lowercase) -> unit object
    .PARAMETER Units
        Array of unit objects from the API
    .OUTPUTS
        [hashtable] @{ ById = @{}; ByName = @{}; ByAlias = @{} }
    .EXAMPLE
        $units = Get-MealieUnits -All
        $lookups = Build-UnitLookups -Units $units
        $unit = $lookups.ByName['gram']
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Units
    )
    
    $lookups = @{
        ById    = @{}
        ByName  = @{}
        ByAlias = @{}
    }
    
    foreach ($unit in $Units) {
        # By ID
        if ($unit.id) {
            $lookups.ById[$unit.id] = $unit
        }
        
        # By name (lowercase)
        if (![string]::IsNullOrEmpty($unit.name)) {
            $nameKey = $unit.name.ToLower().Trim()
            $lookups.ByName[$nameKey] = $unit
        }
        
        # By pluralName (lowercase)
        if (![string]::IsNullOrEmpty($unit.pluralName)) {
            $pluralKey = $unit.pluralName.ToLower().Trim()
            if (-not $lookups.ByName.ContainsKey($pluralKey)) {
                $lookups.ByName[$pluralKey] = $unit
            }
        }
        
        # By abbreviation (lowercase)
        if (![string]::IsNullOrEmpty($unit.abbreviation)) {
            $abbrKey = $unit.abbreviation.ToLower().Trim()
            if (-not $lookups.ByName.ContainsKey($abbrKey)) {
                $lookups.ByName[$abbrKey] = $unit
            }
        }
        
        # By pluralAbbreviation (lowercase)
        if (![string]::IsNullOrEmpty($unit.pluralAbbreviation)) {
            $pluralAbbrKey = $unit.pluralAbbreviation.ToLower().Trim()
            if (-not $lookups.ByName.ContainsKey($pluralAbbrKey)) {
                $lookups.ByName[$pluralAbbrKey] = $unit
            }
        }
        
        # By alias (lowercase)
        if ($unit.aliases -and $unit.aliases.Count -gt 0) {
            foreach ($alias in $unit.aliases) {
                if (![string]::IsNullOrEmpty($alias.name)) {
                    $aliasKey = $alias.name.ToLower().Trim()
                    if (-not $lookups.ByAlias.ContainsKey($aliasKey)) {
                        $lookups.ByAlias[$aliasKey] = $unit
                    }
                }
            }
        }
    }
    
    return $lookups
}

function Build-SimpleLookup {
    <#
    .SYNOPSIS
        Build a simple name-based lookup table
    .DESCRIPTION
        Creates a hashtable for matching by name (case-insensitive).
        Used for Labels, Categories, Tags, and Tools.
    .PARAMETER Items
        Array of objects with at least id and name properties
    .OUTPUTS
        [hashtable] @{ ById = @{}; ByName = @{} }
    .EXAMPLE
        $labels = Get-MealieLabels -All
        $lookup = Build-SimpleLookup -Items $labels
        $label = $lookup.ByName['groente']
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Items
    )
    
    $lookup = @{
        ById   = @{}
        ByName = @{}
    }
    
    foreach ($item in $Items) {
        # By ID
        if ($item.id) {
            $lookup.ById[$item.id] = $item
        }
        
        # By name (lowercase)
        if (![string]::IsNullOrEmpty($item.name)) {
            $nameKey = $item.name.ToLower().Trim()
            $lookup.ByName[$nameKey] = $item
        }
    }
    
    return $lookup
}

function Build-LabelLookup {
    <#
    .SYNOPSIS
        Build a label lookup table
    .DESCRIPTION
        Convenience wrapper around Build-SimpleLookup for labels.
        Returns the ByName hashtable directly for backward compatibility.
    .PARAMETER Labels
        Array of label objects from the API
    .OUTPUTS
        [hashtable] name (lowercase) -> label object
    .EXAMPLE
        $labels = Get-MealieLabels -All
        $lookup = Build-LabelLookup -Labels $labels
        $labelId = $lookup['groente'].id
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Labels
    )
    
    $result = Build-SimpleLookup -Items $Labels
    return $result.ByName
}

function Add-ItemToLookups {
    <#
    .SYNOPSIS
        Add a new or simulated item to lookups for conflict detection
    .DESCRIPTION
        Used during import to register newly created items in lookups, enabling
        import-to-import conflict detection within the same batch.
        Adds _isFromImport marker to distinguish from Mealie items.
    .PARAMETER Lookups
        The lookups hashtable (modified in place)
    .PARAMETER Item
        The import item to add
    .PARAMETER SimulatedId
        A unique ID for the simulated item (used when actual ID isn't available)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Lookups,
        
        [Parameter(Mandatory)]
        [object]$Item,
        
        [string]$SimulatedId
    )
    
    # Create a pseudo-object for the lookups
    $id = if ($SimulatedId) { $SimulatedId } else { [guid]::NewGuid().ToString() }
    $pseudoItem = @{
        id            = $id
        name          = $Item.name
        pluralName    = $Item.pluralName
        aliases       = $Item.aliases
        _isFromImport = $true  # Marker to identify items added during this import
    }
    
    # Add to ById
    $Lookups.ById[$id] = $pseudoItem
    
    # Add to ByName (name)
    if (![string]::IsNullOrEmpty($Item.name)) {
        $nameKey = $Item.name.ToLower().Trim()
        if (-not $Lookups.ByName.ContainsKey($nameKey)) {
            $Lookups.ByName[$nameKey] = $pseudoItem
        }
    }
    
    # Add to ByName (pluralName)
    if (![string]::IsNullOrEmpty($Item.pluralName)) {
        $pluralKey = $Item.pluralName.ToLower().Trim()
        if (-not $Lookups.ByName.ContainsKey($pluralKey)) {
            $Lookups.ByName[$pluralKey] = $pseudoItem
        }
    }
    
    # Add to ByAlias
    if ($Item.aliases -and $Item.aliases.Count -gt 0) {
        foreach ($alias in $Item.aliases) {
            $aliasName = if ($alias -is [string]) { $alias } else { $alias.name }
            if (![string]::IsNullOrEmpty($aliasName)) {
                $aliasKey = $aliasName.ToLower().Trim()
                if (-not $Lookups.ByAlias.ContainsKey($aliasKey)) {
                    $Lookups.ByAlias[$aliasKey] = $pseudoItem
                }
            }
        }
    }
    
    return $id
}

function Get-FoodRecipeUsage {
    <#
    .SYNOPSIS
        Check if a food item is used in any recipes
    .DESCRIPTION
        Queries the Mealie API to determine how many recipes use a specific food item.
        Uses the recipe query filter to efficiently get the count without fetching
        full recipe data.
    .PARAMETER FoodId
        The GUID of the food item to check
    .OUTPUTS
        [hashtable] @{ FoodId = "..."; RecipeCount = N }
    .EXAMPLE
        $usage = Get-FoodRecipeUsage -FoodId "12345-abcde-..."
        if ($usage.RecipeCount -gt 0) {
            Write-Host "Food is used in $($usage.RecipeCount) recipe(s)"
        }
    .NOTES
        Uses the Mealie API query filter: recipeIngredient.food.id = "{food-id}"
        Returns only the count (perPage=1) for efficiency.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$FoodId
    )
    
    try {
        # Build the query filter for recipes using this food
        # The filter searches for recipes where any ingredient's food.id matches
        $filter = [System.Uri]::EscapeDataString("recipeIngredient.food.id = `"$FoodId`"")
        $endpoint = "/api/recipes?queryFilter=$filter&perPage=1"
        
        $response = Invoke-MealieRequest -Endpoint $endpoint -Method 'GET'
        
        # The response contains a 'total' field with the count
        $count = if ($null -ne $response.total) { $response.total } else { 0 }
        
        return @{
            FoodId      = $FoodId
            RecipeCount = $count
        }
    }
    catch {
        Write-Warning "Failed to check recipe usage for food $FoodId : $_"
        # Return 0 on error - fail open to allow deletion if API is having issues
        # This is a conscious design choice: API errors shouldn't block operations
        return @{
            FoodId      = $FoodId
            RecipeCount = 0
            Error       = $_.Exception.Message
        }
    }
}

function Test-FoodsInUse {
    <#
    .SYNOPSIS
        Check multiple food items for recipe usage
    .DESCRIPTION
        Batch checks an array of food items to determine which are used in recipes.
        Returns a structured report separating used items from safe-to-delete items.
        Used by Mirror operations to block deletion of foods that are in use.
    .PARAMETER Foods
        Array of food objects with at least .id and .name properties
    .OUTPUTS
        [hashtable] @{
            HasUsedItems = $true/$false
            UsedItems = @( @{ Id = "..."; Name = "..."; RecipeCount = N }, ... )
            SafeToDelete = @( @{ Id = "..."; Name = "..." }, ... )
        }
    .EXAMPLE
        $toDelete = @(
            @{ id = "abc-123"; name = "komijn" },
            @{ id = "def-456"; name = "kokos" }
        )
        $result = Test-FoodsInUse -Foods $toDelete
        if ($result.HasUsedItems) {
            Write-Host "Cannot delete $($result.UsedItems.Count) item(s) - in use"
        }
    .NOTES
        Makes one API call per food item. For large batches, consider the performance impact.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Foods
    )
    
    $result = @{
        HasUsedItems = $false
        UsedItems    = @()
        SafeToDelete = @()
    }
    
    # Handle empty input
    if ($Foods.Count -eq 0) {
        return $result
    }
    
    $total = $Foods.Count
    $current = 0
    
    foreach ($food in $Foods) {
        $current++
        
        # Show progress for batches of 3+ items
        if ($total -ge 3) {
            Write-Verbose "Checking recipe usage: $current/$total - $($food.name)"
        }
        
        # Get recipe usage count for this food
        $usage = Get-FoodRecipeUsage -FoodId $food.id
        
        if ($usage.RecipeCount -gt 0) {
            # Food is used in recipes - cannot delete
            $result.UsedItems += @{
                Id          = $food.id
                Name        = $food.name
                RecipeCount = $usage.RecipeCount
            }
        }
        else {
            # Food is not used - safe to delete
            $result.SafeToDelete += @{
                Id   = $food.id
                Name = $food.name
            }
        }
    }
    
    # Set flag if any items are in use
    $result.HasUsedItems = ($result.UsedItems.Count -gt 0)
    
    return $result
}

# Note: Find-ExistingItem has been moved to Import-Helpers.ps1
