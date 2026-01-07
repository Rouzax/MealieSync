#Requires -Version 7.0
<#
.SYNOPSIS
    Export functions for Mealie organizers (Categories, Tags, Tools)
.DESCRIPTION
    Exports recipe organizers from Mealie to JSON files with the new
    MealieSync format including schema metadata.
    
    Includes:
    - Export-MealieOrganizers: Core function with -Type parameter
    - Export-MealieCategories: Convenience wrapper
    - Export-MealieTags: Convenience wrapper
    - Export-MealieTools: Convenience wrapper
.NOTES
    These are public functions - exported by the module.
#>

function Export-MealieOrganizers {
    <#
    .SYNOPSIS
        Export organizers (categories, tags, or tools) to a JSON file
    .DESCRIPTION
        Exports recipe organizers from Mealie to a JSON file using the
        new MealieSync format with schema metadata.
    .PARAMETER Path
        Path to the output JSON file
    .PARAMETER Type
        The type of organizer to export (Categories, Tags, Tools)
    .PARAMETER WhatIf
        Show what would be exported without writing files
    .PARAMETER Confirm
        Prompt for confirmation before writing files
    .OUTPUTS
        None. Writes JSON file to disk.
    .EXAMPLE
        Export-MealieOrganizers -Path .\Categories.json -Type Categories
    .EXAMPLE
        Export-MealieOrganizers -Path .\Tools.json -Type Tools -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [ValidateSet('Categories', 'Tags', 'Tools')]
        [string]$Type
    )
    
    # Fetch items based on type
    $items = switch ($Type) {
        'Categories' { Get-MealieCategories -All }
        'Tags'       { Get-MealieTags -All }
        'Tools'      { Get-MealieTools -All }
    }
    
    # Transform items for export (sorted alphabetically)
    $exportItems = @($items | Sort-Object name | ForEach-Object { ConvertTo-OrganizerExport -Item $_ -Type $Type })
    
    # Create wrapper with schema
    $wrapper = New-ExportWrapper -Type $Type -Items $exportItems
    
    # Use lowercase type name for display
    $typeName = $Type.ToLower()
    
    if (Write-ExportFile -Path $Path -Data $wrapper -PSCmdlet $PSCmdlet) {
        Write-Host "Exported $($items.Count) $typeName to: $Path" -ForegroundColor Green
    }
    else {
        Write-Host "Would export $($items.Count) $typeName to: $Path" -ForegroundColor Yellow
    }
}

function Export-MealieCategories {
    <#
    .SYNOPSIS
        Export categories to a JSON file
    .DESCRIPTION
        Convenience wrapper for Export-MealieOrganizers -Type Categories.
        Exports all recipe categories from Mealie to a JSON file.
    .PARAMETER Path
        Path to the output JSON file
    .PARAMETER WhatIf
        Show what would be exported without writing files
    .PARAMETER Confirm
        Prompt for confirmation before writing files
    .OUTPUTS
        None. Writes JSON file to disk.
    .EXAMPLE
        Export-MealieCategories -Path .\Categories.json
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Export-MealieOrganizers -Path $Path -Type 'Categories'
}

function Export-MealieTags {
    <#
    .SYNOPSIS
        Export tags to a JSON file
    .DESCRIPTION
        Convenience wrapper for Export-MealieOrganizers -Type Tags.
        Exports all recipe tags from Mealie to a JSON file.
    .PARAMETER Path
        Path to the output JSON file
    .PARAMETER WhatIf
        Show what would be exported without writing files
    .PARAMETER Confirm
        Prompt for confirmation before writing files
    .OUTPUTS
        None. Writes JSON file to disk.
    .EXAMPLE
        Export-MealieTags -Path .\Tags.json
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Export-MealieOrganizers -Path $Path -Type 'Tags'
}

function Export-MealieTools {
    <#
    .SYNOPSIS
        Export tools to a JSON file
    .DESCRIPTION
        Convenience wrapper for Export-MealieOrganizers -Type Tools.
        Exports all kitchen tools from Mealie to a JSON file.
    .PARAMETER Path
        Path to the output JSON file
    .PARAMETER WhatIf
        Show what would be exported without writing files
    .PARAMETER Confirm
        Prompt for confirmation before writing files
    .OUTPUTS
        None. Writes JSON file to disk.
    .EXAMPLE
        Export-MealieTools -Path .\Tools.json
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Export-MealieOrganizers -Path $Path -Type 'Tools'
}
