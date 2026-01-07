#Requires -Version 7.0
<#
.SYNOPSIS
    Export function for Mealie units
.DESCRIPTION
    Exports measurement units from Mealie to JSON files with the new
    MealieSync format including schema metadata.
.NOTES
    This is a public function - exported by the module.
#>

function Export-MealieUnits {
    <#
    .SYNOPSIS
        Export units to a JSON file
    .DESCRIPTION
        Exports all measurement units from Mealie to a JSON file using the
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
        Export-MealieUnits -Path .\Units.json
    .EXAMPLE
        Export-MealieUnits -Path .\Data\Units.json -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    # Fetch all units
    $units = Get-MealieUnits -All
    
    # Transform units for export (sorted alphabetically)
    $exportItems = @($units | Sort-Object name | ForEach-Object { ConvertTo-UnitExport -Unit $_ })
    
    # Create wrapper with schema
    $wrapper = New-ExportWrapper -Type 'Units' -Items $exportItems
    
    if (Write-ExportFile -Path $Path -Data $wrapper -PSCmdlet $PSCmdlet) {
        Write-Host "Exported $($units.Count) units to: $Path" -ForegroundColor Green
    }
    else {
        Write-Host "Would export $($units.Count) units to: $Path" -ForegroundColor Yellow
    }
}
