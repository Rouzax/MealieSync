# PowerShell Module

For scripting or advanced use cases, you can import MealieSync as a PowerShell module and call its functions directly, instead of going through `Invoke-MealieSync.ps1`.

## Setup

```powershell
Import-Module .\MealieApi.psd1

Initialize-MealieApi -BaseUrl "http://localhost:9000" -Token "your-token"
```

`Initialize-MealieApi` must be called before any other function. It stores the configuration in module-scoped state.

## CRUD Operations

Each data type has the same set of functions:

```powershell
# Foods
$foods = Get-MealieFoods -All
New-MealieFood -Name "tempeh" -PluralName "tempeh" -Aliases @("tempe")
Update-MealieFood -Id "guid" -Data @{ description = "Fermented soybeans" }
Remove-MealieFood -Id "guid"

# Units
$units = Get-MealieUnits -All
New-MealieUnit -Name "tablespoon"
Update-MealieUnit -Id "guid" -Data @{ abbreviation = "tbsp" }
Remove-MealieUnit -Id "guid"

# Labels
$labels = Get-MealieLabels -All

# Categories
$categories = Get-MealieCategories -All

# Tags
$tags = Get-MealieTags -All

# Tools
$tools = Get-MealieTools -All
```

## Bulk Operations

```powershell
# Export
Export-MealieFoods -Path .\Foods.json
Export-MealieUnits -Path .\Units.json

# Import
Import-MealieFoods -Path .\Foods.json -UpdateExisting
Import-MealieLabels -Path .\Labels.json

# Mirror (full sync)
Sync-MealieFoods -Path .\Foods.json -Force
Sync-MealieLabels -Path .\Labels.json
```

## Function Naming

- **Public functions** follow the pattern `Verb-MealieNoun` (e.g., `Get-MealieFoods`, `Import-MealieUnits`)
- **Private functions** use `Verb-Noun` without the Mealie prefix (not accessible after module import)

All modifying functions support `-WhatIf` and `-Confirm` via PowerShell's `SupportsShouldProcess`.
