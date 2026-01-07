#Requires -Version 7.0
<#
.SYNOPSIS
    Export function for Mealie labels
.DESCRIPTION
    Exports food labels from Mealie to JSON files with the new
    MealieSync format including schema metadata.
.NOTES
    This is a public function - exported by the module.
#>

function Export-MealieLabels {
    <#
    .SYNOPSIS
        Export labels to a JSON file
    .DESCRIPTION
        Exports all food labels from Mealie to a JSON file using the
        new MealieSync format with schema metadata.
    .PARAMETER Path
        Path to the output JSON file
    .PARAMETER WhatIf
        Show what would be exported without writing files
    .PARAMETER Confirm
        Prompt for confirmation before writing files
    .OUTPUTS
        None. Writes JSON file to disk.
    .EXAMPLE
        Export-MealieLabels -Path .\Labels.json
    .EXAMPLE
        Export-MealieLabels -Path .\Data\Labels.json -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    # Fetch all labels
    $labels = Get-MealieLabels -All
    
    # Transform labels for export (sorted alphabetically)
    $exportItems = @($labels | Sort-Object name | ForEach-Object { ConvertTo-LabelExport -Label $_ })
    
    # Create wrapper with schema
    $wrapper = New-ExportWrapper -Type 'Labels' -Items $exportItems
    
    if (Write-ExportFile -Path $Path -Data $wrapper -PSCmdlet $PSCmdlet) {
        Write-Host "Exported $($labels.Count) labels to: $Path" -ForegroundColor Green
    }
    else {
        Write-Host "Would export $($labels.Count) labels to: $Path" -ForegroundColor Yellow
    }
}
