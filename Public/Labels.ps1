#Requires -Version 7.0
<#
.SYNOPSIS
    Labels CRUD functions for MealieSync
.DESCRIPTION
    Provides CRUD operations for Mealie food labels:
    - Get-MealieLabels: Retrieve labels with pagination
    - New-MealieLabel: Create a new label
    - Update-MealieLabel: Update an existing label
    - Remove-MealieLabel: Delete a label
    
    Labels are used to categorize foods (ingredients) in Mealie.
.NOTES
    These are public functions - exported by the module.
    Labels use the /api/groups/labels endpoint.
#>

function Get-MealieLabels {
    <#
    .SYNOPSIS
        Get labels from Mealie
    .DESCRIPTION
        Retrieves food labels from Mealie with support for pagination.
        Use -All to retrieve all labels across multiple pages.
    .PARAMETER All
        Retrieve all labels (handles pagination automatically)
    .OUTPUTS
        [array] Array of label objects
    .EXAMPLE
        # Get first page of labels
        $labels = Get-MealieLabels
    .EXAMPLE
        # Get all labels
        $allLabels = Get-MealieLabels -All
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
        $response = Invoke-MealieRequest -Endpoint "/api/groups/labels?page=$page&perPage=$perPage" -Method 'GET'
        $items += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $items
}

function New-MealieLabel {
    <#
    .SYNOPSIS
        Create a new label in Mealie
    .DESCRIPTION
        Creates a new food label in Mealie with the specified name and color.
    .PARAMETER Name
        The name of the label (required)
    .PARAMETER Color
        The color of the label in hex format (default: "#1976D2" - blue)
    .OUTPUTS
        [object] The created label object from the API
    .EXAMPLE
        New-MealieLabel -Name "Groente"
    .EXAMPLE
        # With custom color
        New-MealieLabel -Name "Vlees" -Color "#D32F2F"
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [ValidatePattern('^#[0-9A-Fa-f]{6}$')]
        [string]$Color = "#1976D2"
    )
    
    $body = @{
        name  = $Name
        color = $Color
    }
    
    return Invoke-MealieRequest -Endpoint '/api/groups/labels' -Method 'POST' -Body $body
}

function Update-MealieLabel {
    <#
    .SYNOPSIS
        Update an existing label in Mealie
    .DESCRIPTION
        Updates an existing label with the specified data.
        Only non-null values in the Data hashtable are sent to the API.
    .PARAMETER Id
        The UUID of the label to update
    .PARAMETER Data
        Hashtable containing the fields to update (name, color)
    .OUTPUTS
        [object] The updated label object from the API
    .EXAMPLE
        Update-MealieLabel -Id "abc-123" -Data @{ color = "#4CAF50" }
    .EXAMPLE
        # Update name and color
        Update-MealieLabel -Id $label.id -Data @{ name = "Verse Groente"; color = "#8BC34A" }
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
    
    return Invoke-MealieRequest -Endpoint "/api/groups/labels/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieLabel {
    <#
    .SYNOPSIS
        Delete a label from Mealie
    .DESCRIPTION
        Permanently deletes a label from Mealie.
        Warning: Foods using this label will no longer have a label.
    .PARAMETER Id
        The UUID of the label to delete
    .OUTPUTS
        [object] API response
    .EXAMPLE
        Remove-MealieLabel -Id "abc-123"
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/groups/labels/$Id" -Method 'DELETE'
}
