#Requires -Version 5.1
<#
.SYNOPSIS
    Sync Foods and Units data with Mealie
.DESCRIPTION
    Main script to import, export, and synchronize Foods and Units with your Mealie instance.
    
.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Data\Dutch_Foods.json
    Import foods from JSON file (create only, skip existing)

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\Labels
    Import all JSON files from a folder

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting
    Import foods and update any existing entries

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Export -Type Units -JsonPath .\Exports\Units_backup.json
    Export all units to JSON file

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Export -Type Foods -JsonPath .\Exports\Groente.json -Label "Groente"
    Export only foods with label "Groente"

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Export -Type Foods -JsonPath .\Data\Labels -SplitByLabel
    Export foods to separate files per label (Groente.json, Vlees.json, etc.)

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -WhatIf
    Preview what would happen without making changes
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Import', 'Export', 'List')]
    [string]$Action,
    
    [Parameter(Mandatory)]
    [ValidateSet('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools')]
    [string]$Type,
    
    [string]$JsonPath,
    
    # Import option: import all JSON files from a folder
    [string]$Folder,
    
    [switch]$UpdateExisting,
    
    # Export options for Foods
    [string]$Label,
    
    [switch]$SplitByLabel,
    
    [string]$ConfigPath = ".\mealie-config.json"
)

# Import the module
$modulePath = Join-Path $PSScriptRoot 'MealieApi.psm1'
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}
else {
    throw "Module not found: $modulePath"
}

# Load or create configuration
function Get-MealieConfig {
    param([string]$Path)
    
    if (Test-Path $Path) {
        $config = Get-Content $Path -Raw | ConvertFrom-Json
        return $config
    }
    else {
        Write-Host "Configuration file not found. Creating template..." -ForegroundColor Yellow
        
        $template = @{
            BaseUrl = "http://localhost:9000"
            Token   = "YOUR_API_TOKEN_HERE"
        }
        
        $template | ConvertTo-Json | Set-Content $Path -Encoding UTF8
        Write-Host "Created config template at: $Path" -ForegroundColor Cyan
        Write-Host "Please edit the file with your Mealie URL and API token." -ForegroundColor Cyan
        Write-Host "`nTo get your API token:"
        Write-Host "  1. Go to your Mealie instance"
        Write-Host "  2. Navigate to: /user/profile/api-tokens"
        Write-Host "  3. Create a new token and copy it to the config file"
        exit 1
    }
}

# Main execution
try {
    # Get configuration
    $configFullPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
        $ConfigPath
    }
    else {
        Join-Path $PSScriptRoot $ConfigPath
    }
    
    $config = Get-MealieConfig -Path $configFullPath
    
    if ($config.Token -eq "YOUR_API_TOKEN_HERE") {
        Write-Error "Please configure your API token in: $configFullPath"
        exit 1
    }
    
    # Initialize API
    Write-Host "Connecting to Mealie at: $($config.BaseUrl)" -ForegroundColor Cyan
    $connected = Initialize-MealieApi -BaseUrl $config.BaseUrl -Token $config.Token
    
    if (-not $connected) {
        exit 1
    }
    
    # Execute action
    switch ($Action) {
        'Import' {
            # Validate: need either JsonPath or Folder
            if (-not $JsonPath -and -not $Folder) {
                throw "Either -JsonPath or -Folder is required for Import action"
            }
            
            if ($JsonPath -and $Folder) {
                throw "Use either -JsonPath or -Folder, not both"
            }
            
            $importParams = @{}
            
            if ($UpdateExisting) {
                $importParams.UpdateExisting = $true
            }
            
            if ($WhatIfPreference) {
                $importParams.WhatIf = $true
            }
            
            if ($Folder) {
                # Import all JSON files from folder
                $folderPath = if ([System.IO.Path]::IsPathRooted($Folder)) {
                    $Folder
                }
                else {
                    Join-Path (Get-Location) $Folder
                }
                
                if (-not (Test-Path $folderPath -PathType Container)) {
                    throw "Folder not found: $folderPath"
                }
                
                $jsonFiles = Get-ChildItem -Path $folderPath -Filter "*.json" | Sort-Object Name
                
                if ($jsonFiles.Count -eq 0) {
                    Write-Warning "No JSON files found in: $folderPath"
                    return
                }
                
                Write-Host "`nImporting $Type from folder: $folderPath" -ForegroundColor Cyan
                Write-Host "Found $($jsonFiles.Count) JSON file(s)`n" -ForegroundColor Cyan
                
                # Combined stats
                $totalStats = @{
                    Created       = 0
                    Updated       = 0
                    Unchanged     = 0
                    Skipped       = 0
                    Errors        = 0
                    LabelWarnings = 0
                }
                
                foreach ($file in $jsonFiles) {
                    Write-Host "── $($file.Name) ──" -ForegroundColor White
                    $importParams.Path = $file.FullName
                    
                    $result = switch ($Type) {
                        'Foods' { Import-MealieFoods @importParams }
                        'Units' { Import-MealieUnits @importParams }
                        'Labels' { Import-MealieLabels @importParams }
                        'Categories' { Import-MealieOrganizers @importParams -Type 'Categories' }
                        'Tags' { Import-MealieOrganizers @importParams -Type 'Tags' }
                        'Tools' { Import-MealieOrganizers @importParams -Type 'Tools' }
                    }
                    
                    # Aggregate stats
                    if ($result) {
                        $totalStats.Created += $result.Created
                        $totalStats.Updated += $result.Updated
                        $totalStats.Unchanged += $result.Unchanged
                        $totalStats.Skipped += $result.Skipped
                        $totalStats.Errors += $result.Errors
                        if ($result.LabelWarnings) {
                            $totalStats.LabelWarnings += $result.LabelWarnings
                        }
                    }
                    
                    Write-Host ""
                }
                
                # Show combined totals
                Write-Host "═══════════════════════════════════" -ForegroundColor Cyan
                Write-Host "Combined Totals ($($jsonFiles.Count) files):" -ForegroundColor Cyan
                Write-Host "  Created:       $($totalStats.Created)"
                Write-Host "  Updated:       $($totalStats.Updated)"
                Write-Host "  Unchanged:     $($totalStats.Unchanged)"
                Write-Host "  Skipped:       $($totalStats.Skipped)"
                Write-Host "  Errors:        $($totalStats.Errors)"
                if ($totalStats.LabelWarnings -gt 0) {
                    Write-Host "  LabelWarnings: $($totalStats.LabelWarnings)" -ForegroundColor Yellow
                }
            }
            else {
                # Import single file (existing behavior)
                $fullPath = if ([System.IO.Path]::IsPathRooted($JsonPath)) {
                    $JsonPath
                }
                else {
                    Join-Path (Get-Location) $JsonPath
                }
                
                Write-Host "`nImporting $Type from: $fullPath" -ForegroundColor Cyan
                
                $importParams.Path = $fullPath
                
                switch ($Type) {
                    'Foods' { Import-MealieFoods @importParams }
                    'Units' { Import-MealieUnits @importParams }
                    'Labels' { Import-MealieLabels @importParams }
                    'Categories' { Import-MealieOrganizers @importParams -Type 'Categories' }
                    'Tags' { Import-MealieOrganizers @importParams -Type 'Tags' }
                    'Tools' { Import-MealieOrganizers @importParams -Type 'Tools' }
                }
            }
        }
        
        'Export' {
            if (-not $JsonPath) {
                throw "JsonPath is required for Export action"
            }
            
            $fullPath = if ([System.IO.Path]::IsPathRooted($JsonPath)) {
                $JsonPath
            }
            else {
                Join-Path (Get-Location) $JsonPath
            }
            
            if ($SplitByLabel) {
                Write-Host "`nExporting $Type to folder: $fullPath (split by label)" -ForegroundColor Cyan
            }
            elseif ($Label) {
                Write-Host "`nExporting $Type with label '$Label' to: $fullPath" -ForegroundColor Cyan
            }
            else {
                Write-Host "`nExporting $Type to: $fullPath" -ForegroundColor Cyan
            }
            
            switch ($Type) {
                'Foods' {
                    $exportParams = @{ Path = $fullPath }
                    if ($Label) { $exportParams.Label = $Label }
                    if ($SplitByLabel) { $exportParams.SplitByLabel = $true }
                    Export-MealieFoods @exportParams
                }
                'Units' { Export-MealieUnits -Path $fullPath }
                'Labels' { Export-MealieLabels -Path $fullPath }
                'Categories' { Export-MealieCategories -Path $fullPath }
                'Tags' { Export-MealieTags -Path $fullPath }
                'Tools' { Export-MealieTools -Path $fullPath }
            }
        }
        
        'List' {
            Write-Host "`nListing $Type from Mealie:" -ForegroundColor Cyan
            
            switch ($Type) {
                'Foods' {
                    $items = Get-MealieFoods -All
                    $items | Select-Object name, pluralName, @{N = 'label'; E = { $_.label.name } }, @{N = 'aliases'; E = { ($_.aliases.name -join ', ') } } | 
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) foods"
                }
                'Units' {
                    $items = Get-MealieUnits -All
                    $items | Select-Object name, pluralName, abbreviation, @{N = 'aliases'; E = { ($_.aliases.name -join ', ') } } |
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) units"
                }
                'Labels' {
                    $items = Get-MealieLabels -All
                    $items | Select-Object name, color |
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) labels"
                }
                'Categories' {
                    $items = Get-MealieCategories -All
                    $items | Select-Object name, slug |
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) categories"
                }
                'Tags' {
                    $items = Get-MealieTags -All
                    $items | Select-Object name, slug |
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) tags"
                }
                'Tools' {
                    $items = Get-MealieTools -All
                    $items | Select-Object name, slug |
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) tools"
                }
            }
        }
    }
    
    Write-Host "`nDone!" -ForegroundColor Green
}
catch {
    Write-Error "Error: $_"
    exit 1
}