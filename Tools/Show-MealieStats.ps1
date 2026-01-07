#Requires -Version 7.0
<#
.SYNOPSIS
    Display statistics dashboard for Mealie data
.DESCRIPTION
    Connects to Mealie and displays counts for all data types:
    - Foods (ingredients) with label distribution
    - Units
    - Labels
    - Categories
    - Tags
    - Tools

    This is a standalone utility script that uses the MealieApi module.
.PARAMETER ConfigPath
    Path to mealie-config.json file. Defaults to mealie-config.json in the
    MealieSync folder.
.PARAMETER SkipLabelDistribution
    Skip the detailed breakdown of foods per label
.EXAMPLE
    .\Tools\Show-MealieStats.ps1
    # Full dashboard with label distribution
.EXAMPLE
    .\Tools\Show-MealieStats.ps1 -ConfigPath "C:\configs\mealie-config.json"
    # Uses custom config file
.EXAMPLE
    .\Tools\Show-MealieStats.ps1 -SkipLabelDistribution
    # Show summary only, skip label breakdown
.NOTES
    Author: MealieSync Project
    Version: 2.0.0
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    
    [switch]$SkipLabelDistribution
)

# Determine script location and module path
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent $scriptRoot
$modulePath = Join-Path $moduleRoot "MealieApi.psd1"

# Import the MealieApi module
if (-not (Test-Path $modulePath)) {
    Write-Error "Module not found at: $modulePath"
    exit 1
}

Import-Module $modulePath -Force

# Find config file
if ([string]::IsNullOrEmpty($ConfigPath)) {
    $ConfigPath = Join-Path $moduleRoot "mealie-config.json"
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    Write-Host "`nCreate a config file based on mealie-config-sample.json" -ForegroundColor Yellow
    exit 1
}

# Load config and initialize API
try {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $connected = Initialize-MealieApi -BaseUrl $config.BaseUrl -Token $config.Token
    
    if (-not $connected) {
        Write-Error "Failed to connect to Mealie"
        exit 1
    }
}
catch {
    Write-Error "Failed to load config or connect: $_"
    exit 1
}

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "           MEALIE STATISTICS DASHBOARD" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

# Fetch all data with progress
Write-Host "Fetching data from Mealie..." -ForegroundColor Gray

$stats = @{}

# Foods
Write-Host "  Loading foods..." -ForegroundColor Gray -NoNewline
$foods = Get-MealieFoods -All
$stats['Foods'] = $foods.Count
Write-Host " $($foods.Count)" -ForegroundColor Green

# Units
Write-Host "  Loading units..." -ForegroundColor Gray -NoNewline
$units = Get-MealieUnits -All
$stats['Units'] = $units.Count
Write-Host " $($units.Count)" -ForegroundColor Green

# Labels
Write-Host "  Loading labels..." -ForegroundColor Gray -NoNewline
$labels = Get-MealieLabels -All
$stats['Labels'] = $labels.Count
Write-Host " $($labels.Count)" -ForegroundColor Green

# Categories
Write-Host "  Loading categories..." -ForegroundColor Gray -NoNewline
$categories = Get-MealieCategories -All
$stats['Categories'] = $categories.Count
Write-Host " $($categories.Count)" -ForegroundColor Green

# Tags
Write-Host "  Loading tags..." -ForegroundColor Gray -NoNewline
$tags = Get-MealieTags -All
$stats['Tags'] = $tags.Count
Write-Host " $($tags.Count)" -ForegroundColor Green

# Tools
Write-Host "  Loading tools..." -ForegroundColor Gray -NoNewline
$tools = Get-MealieTools -All
$stats['Tools'] = $tools.Count
Write-Host " $($tools.Count)" -ForegroundColor Green

Write-Host ""

# Summary Table
Write-Host ("-" * 40) -ForegroundColor Gray
Write-Host "  SUMMARY" -ForegroundColor White
Write-Host ("-" * 40) -ForegroundColor Gray
Write-Host ""

$maxTypeLen = ($stats.Keys | Measure-Object -Property Length -Maximum).Maximum + 2

foreach ($type in @('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools')) {
    $count = $stats[$type]
    $typeDisplay = $type.PadRight($maxTypeLen)
    $countDisplay = $count.ToString().PadLeft(6)
    
    # Color based on count
    $color = if ($count -eq 0) { "DarkGray" } elseif ($count -lt 10) { "Yellow" } else { "Green" }
    
    Write-Host "  $typeDisplay" -NoNewline
    Write-Host $countDisplay -ForegroundColor $color
}

Write-Host ""
Write-Host "  Total items:" -NoNewline
$total = ($stats.Values | Measure-Object -Sum).Sum
Write-Host " $total".PadLeft(($maxTypeLen + 6) - 12) -ForegroundColor Cyan
Write-Host ""

# Label Distribution for Foods
if (-not $SkipLabelDistribution -and $foods.Count -gt 0) {
    Write-Host ("-" * 40) -ForegroundColor Gray
    Write-Host "  FOODS BY LABEL" -ForegroundColor White
    Write-Host ("-" * 40) -ForegroundColor Gray
    Write-Host ""
    
    # Group foods by label
    $labelGroups = $foods | Group-Object { if ($_.label) { $_.label.name } else { "(No label)" } } | 
        Sort-Object Count -Descending
    
    $maxLabelLen = ($labelGroups.Name | Measure-Object -Property Length -Maximum).Maximum
    if ($maxLabelLen -lt 15) { $maxLabelLen = 15 }
    
    foreach ($group in $labelGroups) {
        $labelName = $group.Name.PadRight($maxLabelLen)
        $count = $group.Count.ToString().PadLeft(5)
        $percentage = [math]::Round(($group.Count / $foods.Count) * 100, 1)
        $bar = "█" * [math]::Min([math]::Floor($percentage / 2), 25)
        
        # Color for no-label items
        $color = if ($group.Name -eq "(No label)") { "Yellow" } else { "Green" }
        
        Write-Host "  $labelName" -NoNewline
        Write-Host $count -ForegroundColor $color -NoNewline
        Write-Host "  " -NoNewline
        Write-Host $bar -ForegroundColor DarkCyan -NoNewline
        Write-Host " $percentage%" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    
    # Show labels without foods
    $usedLabelNames = $foods | Where-Object { $_.label } | ForEach-Object { $_.label.name } | Select-Object -Unique
    $emptyLabels = $labels | Where-Object { $_.name -notin $usedLabelNames }
    
    if ($emptyLabels.Count -gt 0) {
        Write-Host "  Labels without foods:" -ForegroundColor DarkGray
        $emptyLabels | ForEach-Object {
            Write-Host "    - $($_.name)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

# Foods with aliases statistics
if ($foods.Count -gt 0) {
    $foodsWithAliases = @($foods | Where-Object { $_.aliases -and $_.aliases.Count -gt 0 })
    $totalAliases = ($foods | ForEach-Object { if ($_.aliases) { $_.aliases.Count } else { 0 } } | Measure-Object -Sum).Sum
    
    if ($totalAliases -gt 0) {
        Write-Host ("-" * 40) -ForegroundColor Gray
        Write-Host "  ALIASES" -ForegroundColor White
        Write-Host ("-" * 40) -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Foods with aliases:  $($foodsWithAliases.Count)" -ForegroundColor Green
        Write-Host "  Total aliases:       $totalAliases" -ForegroundColor Green
        Write-Host "  Avg aliases/food:    $([math]::Round($totalAliases / $foods.Count, 2))" -ForegroundColor Green
        Write-Host ""
    }
}

# Units with aliases
if ($units.Count -gt 0) {
    $unitsWithAliases = @($units | Where-Object { $_.aliases -and $_.aliases.Count -gt 0 })
    $totalUnitAliases = ($units | ForEach-Object { if ($_.aliases) { $_.aliases.Count } else { 0 } } | Measure-Object -Sum).Sum
    
    if ($totalUnitAliases -gt 0) {
        Write-Host "  Units with aliases:  $($unitsWithAliases.Count)" -ForegroundColor Green
        Write-Host "  Total unit aliases:  $totalUnitAliases" -ForegroundColor Green
        Write-Host ""
    }
}

Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""
