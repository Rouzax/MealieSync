#Requires -Version 7.0
<#
.SYNOPSIS
    Organizers CRUD functions for MealieSync
.DESCRIPTION
    Provides CRUD operations for Mealie recipe organizers:
    - Categories: Recipe categories (e.g., "BBQ", "Desserts")
    - Tags: Recipe tags (e.g., "Quick", "Vegetarian")
    - Tools: Kitchen tools (e.g., "Oven", "Mixer")
    
    Each type has Get, New, Update, and Remove functions.
.NOTES
    These are public functions - exported by the module.
    All organizers use the /api/organizers/{type} endpoint.
#>

#region Categories

function Get-MealieCategories {
    <#
    .SYNOPSIS
        Get categories from Mealie
    .DESCRIPTION
        Retrieves recipe categories from Mealie with support for pagination.
        Use -All to retrieve all categories across multiple pages.
    .PARAMETER All
        Retrieve all categories (handles pagination automatically)
    .OUTPUTS
        [array] Array of category objects
    .EXAMPLE
        $categories = Get-MealieCategories -All
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [switch]$All
    )
    
    $items = @()
    $page = 1
    $perPage = 100
    
    do {
        $response = Invoke-MealieRequest -Endpoint "/api/organizers/categories?page=$page&perPage=$perPage" -Method 'GET'
        $items += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $items
}

function New-MealieCategory {
    <#
    .SYNOPSIS
        Create a new category in Mealie
    .DESCRIPTION
        Creates a new recipe category in Mealie.
    .PARAMETER Name
        The name of the category (required)
    .OUTPUTS
        [object] The created category object from the API
    .EXAMPLE
        New-MealieCategory -Name "BBQ"
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    
    $body = @{
        name = $Name
    }
    
    return Invoke-MealieRequest -Endpoint '/api/organizers/categories' -Method 'POST' -Body $body
}

function Update-MealieCategory {
    <#
    .SYNOPSIS
        Update an existing category in Mealie
    .DESCRIPTION
        Updates an existing category with the specified data.
    .PARAMETER Id
        The UUID of the category to update
    .PARAMETER Data
        Hashtable containing the fields to update (name)
    .OUTPUTS
        [object] The updated category object from the API
    .EXAMPLE
        Update-MealieCategory -Id "abc-123" -Data @{ name = "Grillen" }
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
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/categories/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieCategory {
    <#
    .SYNOPSIS
        Delete a category from Mealie
    .DESCRIPTION
        Permanently deletes a category from Mealie.
        Warning: Recipes using this category will no longer have it.
    .PARAMETER Id
        The UUID of the category to delete
    .OUTPUTS
        [object] API response
    .EXAMPLE
        Remove-MealieCategory -Id "abc-123"
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/categories/$Id" -Method 'DELETE'
}

#endregion Categories

#region Tags

function Get-MealieTags {
    <#
    .SYNOPSIS
        Get tags from Mealie
    .DESCRIPTION
        Retrieves recipe tags from Mealie with support for pagination.
        Use -All to retrieve all tags across multiple pages.
    .PARAMETER All
        Retrieve all tags (handles pagination automatically)
    .OUTPUTS
        [array] Array of tag objects
    .EXAMPLE
        $tags = Get-MealieTags -All
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [switch]$All
    )
    
    $items = @()
    $page = 1
    $perPage = 100
    
    do {
        $response = Invoke-MealieRequest -Endpoint "/api/organizers/tags?page=$page&perPage=$perPage" -Method 'GET'
        $items += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $items
}

function New-MealieTag {
    <#
    .SYNOPSIS
        Create a new tag in Mealie
    .DESCRIPTION
        Creates a new recipe tag in Mealie.
    .PARAMETER Name
        The name of the tag (required)
    .OUTPUTS
        [object] The created tag object from the API
    .EXAMPLE
        New-MealieTag -Name "Vegetarisch"
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    
    $body = @{
        name = $Name
    }
    
    return Invoke-MealieRequest -Endpoint '/api/organizers/tags' -Method 'POST' -Body $body
}

function Update-MealieTag {
    <#
    .SYNOPSIS
        Update an existing tag in Mealie
    .DESCRIPTION
        Updates an existing tag with the specified data.
    .PARAMETER Id
        The UUID of the tag to update
    .PARAMETER Data
        Hashtable containing the fields to update (name)
    .OUTPUTS
        [object] The updated tag object from the API
    .EXAMPLE
        Update-MealieTag -Id "abc-123" -Data @{ name = "Veganistisch" }
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
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/tags/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieTag {
    <#
    .SYNOPSIS
        Delete a tag from Mealie
    .DESCRIPTION
        Permanently deletes a tag from Mealie.
        Warning: Recipes using this tag will no longer have it.
    .PARAMETER Id
        The UUID of the tag to delete
    .OUTPUTS
        [object] API response
    .EXAMPLE
        Remove-MealieTag -Id "abc-123"
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/tags/$Id" -Method 'DELETE'
}

#endregion Tags

#region Tools

function Get-MealieTools {
    <#
    .SYNOPSIS
        Get tools from Mealie
    .DESCRIPTION
        Retrieves kitchen tools from Mealie with support for pagination.
        Use -All to retrieve all tools across multiple pages.
    .PARAMETER All
        Retrieve all tools (handles pagination automatically)
    .OUTPUTS
        [array] Array of tool objects
    .EXAMPLE
        $tools = Get-MealieTools -All
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [switch]$All
    )
    
    $items = @()
    $page = 1
    $perPage = 100
    
    do {
        $response = Invoke-MealieRequest -Endpoint "/api/organizers/tools?page=$page&perPage=$perPage" -Method 'GET'
        $items += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $items
}

function New-MealieTool {
    <#
    .SYNOPSIS
        Create a new tool in Mealie
    .DESCRIPTION
        Creates a new kitchen tool in Mealie.
    .PARAMETER Name
        The name of the tool (required)
    .OUTPUTS
        [object] The created tool object from the API
    .EXAMPLE
        New-MealieTool -Name "Oven"
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    
    $body = @{
        name = $Name
    }
    
    return Invoke-MealieRequest -Endpoint '/api/organizers/tools' -Method 'POST' -Body $body
}

function Update-MealieTool {
    <#
    .SYNOPSIS
        Update an existing tool in Mealie
    .DESCRIPTION
        Updates an existing tool with the specified data.
    .PARAMETER Id
        The UUID of the tool to update
    .PARAMETER Data
        Hashtable containing the fields to update (name)
    .OUTPUTS
        [object] The updated tool object from the API
    .EXAMPLE
        Update-MealieTool -Id "abc-123" -Data @{ name = "Convectieoven" }
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
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/tools/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieTool {
    <#
    .SYNOPSIS
        Delete a tool from Mealie
    .DESCRIPTION
        Permanently deletes a tool from Mealie.
        Warning: Recipes using this tool will no longer have it.
    .PARAMETER Id
        The UUID of the tool to delete
    .OUTPUTS
        [object] API response
    .EXAMPLE
        Remove-MealieTool -Id "abc-123"
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/tools/$Id" -Method 'DELETE'
}

#endregion Tools
