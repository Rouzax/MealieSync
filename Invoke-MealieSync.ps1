#Requires -Version 5.1
<#
.SYNOPSIS
    Sync Foods and Units data with Mealie
.DESCRIPTION
    Main script to import, export, and synchronize Foods and Units with your Mealie instance.
    
.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json
    Import foods from JSON file (create only, skip existing)

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting
    Import foods and update any existing entries

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Export -Type Units -JsonPath .\Units_backup.json
    Export all units to JSON file

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
    
    [switch]$UpdateExisting,
    
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
            if (-not $JsonPath) {
                throw "JsonPath is required for Import action"
            }
            
            $fullPath = if ([System.IO.Path]::IsPathRooted($JsonPath)) {
                $JsonPath
            }
            else {
                Join-Path (Get-Location) $JsonPath
            }
            
            Write-Host "`nImporting $Type from: $fullPath" -ForegroundColor Cyan
            
            $importParams = @{
                Path = $fullPath
            }
            
            if ($UpdateExisting) {
                $importParams.UpdateExisting = $true
            }
            
            if ($WhatIfPreference) {
                $importParams.WhatIf = $true
            }
            
            switch ($Type) {
                'Foods' { Import-MealieFoods @importParams }
                'Units' { Import-MealieUnits @importParams }
                'Labels' { Import-MealieLabels @importParams }
                'Categories' { Import-MealieOrganizers @importParams -Type 'Categories' }
                'Tags' { Import-MealieOrganizers @importParams -Type 'Tags' }
                'Tools' { Import-MealieOrganizers @importParams -Type 'Tools' }
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
            
            Write-Host "`nExporting $Type to: $fullPath" -ForegroundColor Cyan
            
            switch ($Type) {
                'Foods' { Export-MealieFoods -Path $fullPath }
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
                    $items | Select-Object name, pluralName, @{N = 'aliases'; E = { ($_.aliases.name -join ', ') } } | 
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