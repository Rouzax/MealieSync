#Requires -Version 7.0
<#
.SYNOPSIS
    Export function for Mealie foods
.DESCRIPTION
    Exports foods (ingredients) from Mealie to JSON files with the new
    MealieSync format including schema metadata.
.NOTES
    This is a public function - exported by the module.
#>

function Export-MealieFoods {
    <#
    .SYNOPSIS
        Export foods to JSON file(s)
    .DESCRIPTION
        Exports food items from Mealie to JSON files using the new MealieSync format
        with schema metadata. Supports filtering by label and splitting into
        multiple files by label.
    .PARAMETER Path
        Path to the JSON file (or folder when using -SplitByLabel)
    .PARAMETER Label
        Export only foods with this label name
    .PARAMETER SplitByLabel
        Export to separate files per label. Path should be a folder.
        Files are named after the label (e.g., Groente.json, Vlees.json)
    .PARAMETER WhatIf
        Show what would be exported without writing files
    .PARAMETER Confirm
        Prompt for confirmation before writing files
    .OUTPUTS
        None. Writes JSON file(s) to disk.
    .EXAMPLE
        Export-MealieFoods -Path .\Foods.json
        # Exports all foods to single file with new format
    .EXAMPLE
        Export-MealieFoods -Path .\Foods.json -Label "Groente"
        # Exports only foods with label "Groente"
    .EXAMPLE
        Export-MealieFoods -Path .\FoodsExport -SplitByLabel
        # Exports to FoodsExport\Groente.json, FoodsExport\Vlees.json, etc.
    .EXAMPLE
        Export-MealieFoods -Path .\Foods.json -WhatIf
        # Shows what would be exported without writing
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Label,
        
        [switch]$SplitByLabel
    )
    
    # Fetch all foods
    $foods = Get-MealieFoods -All
    
    if ($SplitByLabel) {
        # Create output folder if needed
        if (-not (Test-Path $Path)) {
            if ($PSCmdlet.ShouldProcess($Path, "Create directory")) {
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }
        }
        
        # Group foods by label
        $grouped = $foods | Group-Object { if ($_.label) { $_.label.name } else { "_No_Label" } }
        
        $totalExported = 0
        foreach ($group in $grouped) {
            # Sanitize filename (remove invalid characters)
            $safeName = $group.Name -replace '[\\/:*?"<>|]', '_'
            $filePath = Join-Path $Path "$safeName.json"
            
            # Transform foods for export (sorted alphabetically)
            $exportItems = @($group.Group | Sort-Object name | ForEach-Object { ConvertTo-FoodExport -Food $_ })
            
            # Create wrapper with schema
            $wrapper = New-ExportWrapper -Type 'Foods' -Items $exportItems
            
            if (Write-ExportFile -Path $filePath -Data $wrapper -PSCmdlet $PSCmdlet) {
                Write-Host "  Exported $($group.Count) foods to: $filePath" -ForegroundColor Green
            }
            else {
                Write-Host "  Would export $($group.Count) foods to: $filePath" -ForegroundColor Yellow
            }
            $totalExported += $group.Count
        }
        
        Write-Host "`nTotal: $totalExported foods in $($grouped.Count) files" -ForegroundColor Cyan
    }
    elseif ($Label) {
        # Filter by specific label
        $filtered = $foods | Where-Object { $_.label -and $_.label.name -eq $Label }
        
        if ($filtered.Count -eq 0) {
            Write-Warning "No foods found with label: $Label"
            return
        }
        
        # Transform foods for export (sorted alphabetically)
        $exportItems = @($filtered | Sort-Object name | ForEach-Object { ConvertTo-FoodExport -Food $_ })
        
        # Create wrapper with schema
        $wrapper = New-ExportWrapper -Type 'Foods' -Items $exportItems
        
        if (Write-ExportFile -Path $Path -Data $wrapper -PSCmdlet $PSCmdlet) {
            Write-Host "Exported $($filtered.Count) foods with label '$Label' to: $Path" -ForegroundColor Green
        }
        else {
            Write-Host "Would export $($filtered.Count) foods with label '$Label' to: $Path" -ForegroundColor Yellow
        }
    }
    else {
        # Export all to single file (sorted alphabetically)
        $exportItems = @($foods | Sort-Object name | ForEach-Object { ConvertTo-FoodExport -Food $_ })
        
        # Create wrapper with schema
        $wrapper = New-ExportWrapper -Type 'Foods' -Items $exportItems
        
        if (Write-ExportFile -Path $Path -Data $wrapper -PSCmdlet $PSCmdlet) {
            Write-Host "Exported $($foods.Count) foods to: $Path" -ForegroundColor Green
        }
        else {
            Write-Host "Would export $($foods.Count) foods to: $Path" -ForegroundColor Yellow
        }
    }
}
