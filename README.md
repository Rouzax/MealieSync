# MealieSync

PowerShell module and scripts for managing data in [Mealie](https://mealie.io) via the REST API.

## Features

- **Import & Export** — Sync data from JSON files to your Mealie instance
- **Multiple data types** — Foods, Units, Labels, Categories, Tags, Tools
- **Smart updates** — Create new items or update existing ones
- **Progress tracking** — Visual progress bar during imports
- **Rate limiting** — Configurable throttling to avoid API overload
- **WhatIf support** — Preview changes before applying
- **Dutch data included** — Extended Dutch ingredient, unit, and category lists

## Supported Data Types

| Type | Description | Endpoint |
|------|-------------|----------|
| Foods | Ingredients with aliases | `/api/foods` |
| Units | Measurement units with abbreviations | `/api/units` |
| Labels | Color-coded labels for foods | `/api/groups/labels` |
| Categories | Recipe categories | `/api/organizers/categories` |
| Tags | Recipe tags | `/api/organizers/tags` |
| Tools | Kitchen equipment | `/api/organizers/tools` |

## Prerequisites

- PowerShell 5.1 or later (Windows PowerShell or PowerShell Core)
- A running Mealie instance (v2.x+)
- An API token from your Mealie instance

## Getting Your API Token

1. Log in to your Mealie instance
2. Navigate to: **Profile → Manage Your API Tokens** (`/user/profile/api-tokens`)
3. Create a new token with a descriptive name (e.g., "PowerShell Scripts")
4. Copy the generated token

## Setup

1. Clone or download this repository
2. Unblock the files (Windows security):
   ```powershell
   Get-ChildItem -Path ".\MealieSync" -Recurse | Unblock-File
   ```
3. Edit `mealie-config.json`:
   ```json
   {
     "BaseUrl": "http://your-mealie-server:9000",
     "Token": "your-api-token-here"
   }
   ```

## Usage

### Quick Start

```powershell
# List current data
.\Invoke-MealieSync.ps1 -Action List -Type Foods
.\Invoke-MealieSync.ps1 -Action List -Type Units
.\Invoke-MealieSync.ps1 -Action List -Type Labels
.\Invoke-MealieSync.ps1 -Action List -Type Categories
.\Invoke-MealieSync.ps1 -Action List -Type Tags
.\Invoke-MealieSync.ps1 -Action List -Type Tools
```

### Backup Your Data

Always backup before making changes:

```powershell
.\Invoke-MealieSync.ps1 -Action Export -Type Foods -JsonPath .\Backup_Foods.json
.\Invoke-MealieSync.ps1 -Action Export -Type Units -JsonPath .\Backup_Units.json
.\Invoke-MealieSync.ps1 -Action Export -Type Labels -JsonPath .\Backup_Labels.json
.\Invoke-MealieSync.ps1 -Action Export -Type Categories -JsonPath .\Backup_Categories.json
.\Invoke-MealieSync.ps1 -Action Export -Type Tags -JsonPath .\Backup_Tags.json
.\Invoke-MealieSync.ps1 -Action Export -Type Tools -JsonPath .\Backup_Tools.json
```

### Import Data

```powershell
# Preview what would happen (dry run)
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Dutch_Foods_Extended.json -WhatIf

# Import new items only (skip existing)
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Dutch_Foods_Extended.json

# Import and update existing items
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Dutch_Foods_Extended.json -UpdateExisting
```

### Understanding -UpdateExisting

| Scenario | Without `-UpdateExisting` | With `-UpdateExisting` |
|----------|---------------------------|------------------------|
| Item doesn't exist | Creates it | Creates it |
| Item already exists | **Skips it** | **Compares & updates if changed** |

The import compares all relevant fields (name, pluralName, aliases, fraction, etc.) and only performs an API update if something actually changed. This means:

- **Efficient**: No unnecessary API calls for unchanged items
- **Accurate stats**: "Updated" count reflects real changes

```
Import Summary:
  Created:       5
  Updated:       3    ← Only items that actually changed
  Unchanged:     42   ← Items that matched exactly
  Skipped:       0
  Errors:        0
  LabelWarnings: 2    ← Labels not found (foods imported without label)
```

Use `-UpdateExisting` when you want to enrich existing entries with aliases, plural names, or other data.

### Recommended Import Order

When using labels on foods, import in this order:

1. **Labels first** — So they exist when foods reference them
2. **Foods second** — Can now link to labels by name

```powershell
# 1. Import labels
.\Invoke-MealieSync.ps1 -Action Import -Type Labels -JsonPath .\Dutch_Labels.json

# 2. Import foods (with label references)
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Dutch_Foods_Extended.json
```

## Using the Module Directly

For advanced usage, import the module directly:

```powershell
Import-Module .\MealieApi.psm1

# Initialize connection
Initialize-MealieApi -BaseUrl "http://localhost:9000" -Token "your-token"

# Foods
$foods = Get-MealieFoods -All
New-MealieFood -Name "tempeh" -PluralName "tempeh" -Aliases @("tempe", "tempé")
Update-MealieFood -Id "guid-here" -Data @{ aliases = @(@{name="alias1"}) }
Remove-MealieFood -Id "guid-here"

# Units
$units = Get-MealieUnits -All
New-MealieUnit -Name "snufje" -PluralName "snufjes" -Fraction $true

# Labels
$labels = Get-MealieLabels -All
New-MealieLabel -Name "Biologisch" -Color "#4CAF50"

# Categories, Tags, Tools
$categories = Get-MealieCategories -All
$tags = Get-MealieTags -All
$tools = Get-MealieTools -All

New-MealieCategory -Name "Hoofdgerecht"
New-MealieTag -Name "Vegetarisch"
New-MealieTool -Name "Airfryer"
```

## Included Dutch Data Files

### Dutch_Foods_Extended.json
~200 Dutch ingredient names with aliases:
- Dutch vegetables, fruits, meats
- Indonesian/Asian ingredients (trassi, sambal, ketjap, tempe, etc.)
- French/Italian ingredients with Dutch names
- Common aliases and spelling variations

### Example_Foods_With_Labels.json
Example file demonstrating label assignment:
- Shows how to link foods to existing labels
- Includes test case for non-existent label (shows warning behavior)

### Dutch_Units_Extended.json
~45 Dutch measurement units:
- Metric units (gram, liter, ml, kg)
- Dutch cooking measurements (eetlepel, theelepel, snufje, scheutje)
- Container units (blik, pot, zakje, bakje)
- Abbreviations and aliases (el, tl, EL, TL)

### Dutch_Labels.json
25 color-coded labels for ingredient categorization:
- Groente, Fruit, Vlees, Vis, Gevogelte
- Zuivel, Kruiden & Specerijen, Bakproducten
- Vegan, Biologisch, Glutenvrij, Lactosevrij

### Dutch_Categories.json
32 recipe categories:
- Hoofdgerecht, Voorgerecht, Nagerecht, Bijgerecht
- Ontbijt, Lunch, Brunch, Snack
- Vegetarisch, Veganistisch, Glutenvrij
- BBQ, Feestelijk, Snel & Makkelijk

### Dutch_Tools.json
60 kitchen tools and equipment:
- Appliances (Oven, Airfryer, Blender, Thermomix)
- Cookware (Koekenpan, Wok, Braadpan)
- Utensils (Garde, Spatel, Rasp, Vergiet)

## JSON Format Reference

### Food
```json
{
  "name": "tomaat",
  "pluralName": "tomaten",
  "description": "",
  "label": "Groente",
  "aliases": [
    {"name": "trostomaat"},
    {"name": "vleestomaat"}
  ]
}
```

**Note:** The `label` field should contain the **name** of an existing label. If the label doesn't exist, a warning is shown and the food is imported without label. This prevents accidental creation of labels with typos.
```

### Unit
```json
{
  "name": "eetlepel",
  "pluralName": "eetlepels",
  "description": "15 ml",
  "abbreviation": "el",
  "pluralAbbreviation": "",
  "useAbbreviation": false,
  "fraction": true,
  "aliases": [
    {"name": "EL"},
    {"name": "eetl."}
  ]
}
```

### Label
```json
{
  "name": "Groente",
  "color": "#4CAF50"
}
```

### Category / Tag / Tool
```json
{
  "name": "Hoofdgerecht"
}
```

## Troubleshooting

### "File cannot be loaded" / Execution Policy Error
```powershell
# Option 1: Unblock downloaded files
Get-ChildItem -Path "." -Recurse | Unblock-File

# Option 2: Set execution policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Failed to connect" Errors
- Verify your Mealie URL is accessible
- Check your API token is valid and not expired
- Ensure no trailing slash in the URL

### "401 Unauthorized" Errors
- Your API token may have expired
- Generate a new token in Mealie

### Items Not Updating
- Use the `-UpdateExisting` flag to update existing items
- Without this flag, existing items are skipped

### Special Characters Not Displaying Correctly
- Ensure your JSON files are saved with UTF-8 encoding
- The module uses UTF-8 for all API requests

## API Reference

The module wraps these Mealie API endpoints:

| Function | Method | Endpoint |
|----------|--------|----------|
| `Get-MealieFoods` | GET | `/api/foods` |
| `New-MealieFood` | POST | `/api/foods` |
| `Update-MealieFood` | PUT | `/api/foods/{id}` |
| `Remove-MealieFood` | DELETE | `/api/foods/{id}` |
| `Get-MealieUnits` | GET | `/api/units` |
| `New-MealieUnit` | POST | `/api/units` |
| `Update-MealieUnit` | PUT | `/api/units/{id}` |
| `Remove-MealieUnit` | DELETE | `/api/units/{id}` |
| `Get-MealieLabels` | GET | `/api/groups/labels` |
| `New-MealieLabel` | POST | `/api/groups/labels` |
| `Update-MealieLabel` | PUT | `/api/groups/labels/{id}` |
| `Remove-MealieLabel` | DELETE | `/api/groups/labels/{id}` |
| `Get-MealieCategories` | GET | `/api/organizers/categories` |
| `New-MealieCategory` | POST | `/api/organizers/categories` |
| `Update-MealieCategory` | PUT | `/api/organizers/categories/{id}` |
| `Remove-MealieCategory` | DELETE | `/api/organizers/categories/{id}` |
| `Get-MealieTags` | GET | `/api/organizers/tags` |
| `New-MealieTag` | POST | `/api/organizers/tags` |
| `Update-MealieTag` | PUT | `/api/organizers/tags/{id}` |
| `Remove-MealieTag` | DELETE | `/api/organizers/tags/{id}` |
| `Get-MealieTools` | GET | `/api/organizers/tools` |
| `New-MealieTool` | POST | `/api/organizers/tools` |
| `Update-MealieTool` | PUT | `/api/organizers/tools/{id}` |
| `Remove-MealieTool` | DELETE | `/api/organizers/tools/{id}` |

## License

MIT — Feel free to modify and use as needed.