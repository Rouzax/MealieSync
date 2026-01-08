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
        - ById: id → food object
        - ByName: name/pluralName (lowercase) → food object
        - ByAlias: alias name (lowercase) → food object
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
        - ById: id → unit object
        - ByName: name/pluralName/abbreviation (lowercase) → unit object
        - ByAlias: alias name (lowercase) → unit object
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
        [hashtable] name (lowercase) → label object
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

#region Tag Merge Support Functions

function Get-MealieTagBySlug {
    <#
    .SYNOPSIS
        Get a tag by slug including its recipe list
    .DESCRIPTION
        Retrieves a tag from Mealie using its slug, including the full list of
        recipes that use this tag. This is the only endpoint that returns recipe
        associations - the ID-based endpoint (/api/organizers/tags/{id}) does NOT
        return recipes.
    .PARAMETER Slug
        The slug of the tag to retrieve (e.g., "vegetarisch", "snel-klaar")
    .OUTPUTS
        [object] Tag object with recipes array, or $null if not found
        The tag object includes:
        - id: Tag UUID
        - name: Tag display name
        - slug: URL-safe identifier
        - groupId: Group UUID
        - recipes: Array of recipe objects (each with at least: id, slug, name)
    .EXAMPLE
        $tag = Get-MealieTagBySlug -Slug "vegetarisch"
        if ($tag) {
            Write-Host "Tag '$($tag.name)' has $($tag.recipes.Count) recipe(s)"
        }
    .EXAMPLE
        # Get recipe slugs for bulk operations
        $tag = Get-MealieTagBySlug -Slug "oosters"
        $recipeSlugs = $tag.recipes | ForEach-Object { $_.slug }
    .NOTES
        Used by the tag merge feature to get source tag recipe associations
        before transferring them to the target tag.
        
        API Endpoint: GET /api/organizers/tags/slug/{slug}
        
        IMPORTANT: The /api/organizers/tags/{id} endpoint does NOT return recipes!
        Always use this slug-based endpoint when you need recipe associations.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Slug
    )
    
    try {
        # URL-encode the slug to handle special characters
        $encodedSlug = [System.Uri]::EscapeDataString($Slug)
        $endpoint = "/api/organizers/tags/slug/$encodedSlug"
        
        $response = Invoke-MealieRequest -Endpoint $endpoint -Method 'GET'
        return $response
    }
    catch {
        # Check if it's a 404 (tag not found)
        if ($_.Exception.Message -match '404|not found') {
            Write-Verbose "Tag with slug '$Slug' not found"
            return $null
        }
        
        # Re-throw other errors
        Write-Error "Failed to get tag by slug '$Slug': $_"
        throw
    }
}

function Add-TagsToRecipes {
    <#
    .SYNOPSIS
        Bulk-add tags to multiple recipes
    .DESCRIPTION
        Uses the Mealie bulk actions API to add one or more tags to multiple
        recipes in a single API call. This is more efficient than updating
        recipes individually and is the recommended approach for tag merge
        operations.
    .PARAMETER RecipeSlugs
        Array of recipe slugs to add tags to
    .PARAMETER Tags
        Array of tag objects to add. Each tag must include:
        - id: Tag UUID (required)
        - name: Tag name (required)
        - slug: Tag slug (required)
        - groupId: Group UUID (required)
    .OUTPUTS
        [object] API response from the bulk action
    .EXAMPLE
        # Add a single tag to multiple recipes
        $tag = @{
            id = "abc-123"
            name = "aziatisch"
            slug = "aziatisch"
            groupId = "group-456"
        }
        Add-TagsToRecipes -RecipeSlugs @("pad-thai", "nasi-goreng") -Tags @($tag)
    .EXAMPLE
        # Get tag from API and add to recipes
        $tags = Get-MealieTags -All
        $asianTag = $tags | Where-Object { $_.slug -eq "aziatisch" }
        $tagData = @{
            id = $asianTag.id
            name = $asianTag.name
            slug = $asianTag.slug
            groupId = $asianTag.groupId
        }
        Add-TagsToRecipes -RecipeSlugs @("rendang", "tom-yum") -Tags @($tagData)
    .NOTES
        Used by the tag merge feature to transfer recipes from source tags
        to the target tag before deleting the source tags.
        
        API Endpoint: POST /api/recipes/bulk-actions/tag
        
        The bulk action is ADDITIVE - it adds the specified tags without
        removing existing tags from the recipes.
        
        Request body format:
        {
          "recipes": ["recipe-slug-1", "recipe-slug-2"],
          "tags": [{ "id": "...", "name": "...", "slug": "...", "groupId": "..." }]
        }
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$RecipeSlugs,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [array]$Tags
    )
    
    # Validate tag objects have required properties
    foreach ($tag in $Tags) {
        $requiredProps = @('id', 'name', 'slug', 'groupId')
        foreach ($prop in $requiredProps) {
            if ([string]::IsNullOrEmpty($tag.$prop)) {
                throw "Tag object is missing required property '$prop'. Each tag must have: $($requiredProps -join ', ')"
            }
        }
    }
    
    # Build the request body
    $body = @{
        recipes = @($RecipeSlugs)
        tags    = @($Tags | ForEach-Object {
            @{
                id      = $_.id
                name    = $_.name
                slug    = $_.slug
                groupId = $_.groupId
            }
        })
    }
    
    try {
        Write-Verbose "Adding $($Tags.Count) tag(s) to $($RecipeSlugs.Count) recipe(s)"
        $response = Invoke-MealieRequest -Endpoint '/api/recipes/bulk-actions/tag' -Method 'POST' -Body $body
        return $response
    }
    catch {
        Write-Error "Failed to add tags to recipes: $_"
        throw
    }
}

function Get-EmptyTags {
    <#
    .SYNOPSIS
        Get all tags that have no recipes
    .DESCRIPTION
        Retrieves a list of tags that are not associated with any recipes.
        Useful for cleanup operations and verifying tag merge results.
    .OUTPUTS
        [array] Array of tag objects with no recipe associations
        Returns empty array if all tags have recipes or if no tags exist.
    .EXAMPLE
        $emptyTags = Get-EmptyTags
        if ($emptyTags.Count -gt 0) {
            Write-Host "Found $($emptyTags.Count) orphaned tag(s)"
            $emptyTags | ForEach-Object { Write-Host "  - $($_.name)" }
        }
    .EXAMPLE
        # Cleanup: Delete all empty tags
        $emptyTags = Get-EmptyTags
        foreach ($tag in $emptyTags) {
            Remove-MealieTag -Id $tag.id
            Write-Host "Deleted empty tag: $($tag.name)"
        }
    .NOTES
        Used by the tag merge feature to verify that source tags were
        properly cleaned up after merging.
        
        API Endpoint: GET /api/organizers/tags/empty
        
        This endpoint returns tags where the recipe count is zero.
        Unlike the standard tags list endpoint, this one specifically
        filters for unused tags.
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param()
    
    try {
        $response = Invoke-MealieRequest -Endpoint '/api/organizers/tags/empty' -Method 'GET'
        
        # Handle different response formats
        # The API might return { items: [...] } or just [...]
        if ($response -is [array]) {
            return $response
        }
        elseif ($response.items) {
            return $response.items
        }
        else {
            # Empty result or unexpected format
            Write-Verbose "No empty tags found or unexpected response format"
            return @()
        }
    }
    catch {
        Write-Error "Failed to get empty tags: $_"
        throw
    }
}

#endregion Tag Merge Support Functions
