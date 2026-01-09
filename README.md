# MealieSync

[![PowerShell 7.0+](https://img.shields.io/badge/PowerShell-7.0%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Mealie v2.x](https://img.shields.io/badge/Mealie-v2.x-green.svg)](https://mealie.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A PowerShell toolkit for managing [Mealie](https://mealie.io) recipe data via REST API. Import, export, and synchronize your ingredients, units, labels, and more—with smart duplicate prevention, change detection, and full bidirectional sync.

```
============================================================
           MEALIE STATISTICS DASHBOARD
============================================================

  Foods         1074        Categories      21
  Units           48        Tags           232
  Labels          29        Tools          121
                            ─────────────────
                            Total:        1525
```

## Why MealieSync?

Mealie's web interface is great for individual edits, but managing hundreds of ingredients or performing bulk updates becomes tedious. MealieSync gives you:

- **Offline editing** — Work on JSON files in your favorite editor, then sync
- **Version control** — Track changes to your ingredient database with Git
- **Bulk operations** — Import entire databases at once
- **AI-friendly** — Use LLMs to generate, translate, or expand ingredient data, then import directly
- **Duplicate prevention** — Smart matching across names, plurals, and aliases
- **Conflict detection** — Catch duplicates within and across JSON files before import
- **Safe previews** — See exactly what will change before committing
- **Full sync** — Mirror your JSON to Mealie exactly (including deletions)
- **Tag consolidation** — Merge multiple tags into one, automatically updating all affected recipes

## Included Data

This repository includes a comprehensive **Dutch ingredient database** ready to import:

| Data Type      |  Count | Description                                   |
| -------------- | -----: | --------------------------------------------- |
| **Foods**      | 1,000+ | Ingredients with aliases across 29 categories |
| **Units**      |     48 | Measurement units with abbreviations          |
| **Labels**     |     29 | Color-coded ingredient categories             |
| **Categories** |     21 | Recipe categories                             |
| **Tools**      |    121 | Kitchen equipment                             |

Community contributions for other languages are welcome! See [Data/README.md](Data/README.md).

| Language | Code | Status                                    |
| -------- | ---- | ----------------------------------------- |
| Dutch    | `nl` | ✅ 1,000+ ingredients, actively maintained |
| English  | `en` | 💬 Open to contributions                   |
| German   | `de` | 💬 Open to contributions                   |
| French   | `fr` | 💬 Open to contributions                   |
| *Other*  | —    | 💬 [Contribute yours!](Data/README.md)     |

---

## Quick Start

### 1. Requirements

- **PowerShell 7.0+** — [Download here](https://github.com/PowerShell/PowerShell/releases)
- **Mealie v2.x** — Running instance with API access
- **API token** — From your Mealie user profile

> ⚠️ Windows PowerShell 5.1 is not supported due to UTF-8 encoding limitations.

### 2. Install

```powershell
# Clone the repository
git clone https://github.com/Rouzax/MealieSync.git
cd MealieSync

# On Windows: unblock downloaded files
Get-ChildItem -Recurse | Unblock-File
```

### 3. Configure

Create `mealie-config.json` in the project root:

```json
{
  "BaseUrl": "http://your-mealie-server:9000",
  "Token": "your-api-token-here"
}
```

To get your API token: **Mealie → Profile → Manage Your API Tokens**

### 4. Test Connection

```powershell
.\Tools\Test-MealieConnection.ps1 -Detailed
```

```
==================================================
     MEALIE CONNECTION TEST
==================================================

Module Check
------------------------------
  [✓] Module found
  [✓] Module loaded

Configuration
------------------------------
  [✓] Config file found
  [✓] Config parsed

Network Connectivity
------------------------------
  [✓] TCP connection - Port reachable

API Authentication
------------------------------
  [✓] Authentication - Token accepted

Endpoint Access Tests
------------------------------
  [✓] Foods - 1074 items
  [✓] Units - 48 items
  [✓] Labels - 29 items
  [✓] Categories - 21 items
  [✓] Tags - 232 items
  [✓] Tools - 121 items

==================================================
  All tests passed! Connection is working.
```

### 5. Import the Dutch Data

```powershell
# Import labels first (foods reference them)
.\Invoke-MealieSync.ps1 -Action Import -Type Labels -JsonPath .\Data\nl\Labels.json

# Import foods (from folder containing all category files)
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\nl\Foods

# Import units, tools, categories
.\Invoke-MealieSync.ps1 -Action Import -Type Units -JsonPath .\Data\nl\Units.json
.\Invoke-MealieSync.ps1 -Action Import -Type Tools -JsonPath .\Data\nl\Tools.json
.\Invoke-MealieSync.ps1 -Action Import -Type Categories -JsonPath .\Data\nl\Categories.json
```

---

## Core Concepts

### Actions

| Action   | Description                                                  |
| -------- | ------------------------------------------------------------ |
| `List`   | Display items currently in Mealie                            |
| `Export` | Save items from Mealie to JSON                               |
| `Import` | Add items from JSON (optionally update existing)             |
| `Mirror` | Full sync: add, update, **and delete** to match JSON exactly |

### Data Types

| Type         | Description                         | Examples                    |
| ------------ | ----------------------------------- | --------------------------- |
| `Foods`      | Ingredients with aliases and labels | tomato, garlic, soy sauce   |
| `Units`      | Measurements with abbreviations     | tablespoon (tbsp), gram (g) |
| `Labels`     | Color-coded food categories         | Vegetables, Meat, Dairy     |
| `Categories` | Recipe categories                   | Main course, Appetizer      |
| `Tags`       | Recipe tags                         | Vegetarian, Quick meals     |
| `Tools`      | Kitchen equipment                   | Oven, Wok, Blender          |

### Smart Matching

MealieSync prevents duplicates through comprehensive cross-matching. For each item being imported, it checks against all existing Mealie items in this order:

```
Import Item                    Mealie Items
───────────                    ────────────
   name        <───────────>   name
   name        <───────────>   pluralName
   name        <───────────>   aliases[]
   pluralName  <───────────>   name
   pluralName  <───────────>   pluralName
   pluralName  <───────────>   aliases[]
   aliases[]   <───────────>   name
   aliases[]   <───────────>   pluralName
   aliases[]   <───────────>   aliases[]
```

**Match priority:**
1. **ID** — Exact UUID match (highest priority, safest for renames)
2. **Name ↔ Name** — Direct name match
3. **Name ↔ PluralName** — Cross-match (e.g., importing "tomatoes" finds existing "tomato")
4. **Name ↔ Alias** — Import name matches existing alias
5. **Alias ↔ Name** — Import alias matches existing name

This ensures that renaming an ingredient (with the same ID) works correctly, and that items aren't duplicated even if the name/plural relationship is reversed.

---

## Usage Examples

### List Items

```powershell
.\Invoke-MealieSync.ps1 -Action List -Type Labels
```

```
name                    color
----                    -----
Aardappelen & Knollen   #8D6E63
Bakproducten            #D7CCC8
Fruit                   #8BC34A
Groente                 #4CAF50
Kruiden & Specerijen    #7B1FA2
Vlees                   #E53935
...

Total: 29 labels
```

### Preview Changes (WhatIf)

Always preview before importing:

```powershell
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting -WhatIf
```

```
Import mode:
  [X] Update existing items
  [ ] Replace aliases (merge mode)

Importing Foods from: .\Foods.json
   4/18 Would UPDATE (matched by name): beet
          description : 'Root vegetable; earthy flavor...' → 'Root vegetable; dark red flesh...'
          label       : 'Vegetables' → 'Root Vegetables'
  12/18 Would UPDATE (matched by pluralName→name): baby potato
          name        : 'baby potatoes' → 'baby potato'
          pluralName  : '(empty)' → 'baby potatoes'
          description : '(empty)' → 'Small potatoes with skin...'

═══════════════════════════════════════════
 Foods Import Summary (WhatIf)
═══════════════════════════════════════════
  Updated         : 2
  Unchanged       : 16
───────────────────────────────────────────
  Total processed : 18
```

### Conflict Detection

MealieSync detects complex conflicts where an item can't be cleanly matched:

```
   9/25 Conflict: fresh dill
          Value 'fresh dill' exists as alias on Mealie item 'dill'
          But 'dill' was already claimed by import item 'dried dill'
          Fix: Remove 'fresh dill' from 'dill' aliases in Mealie

  24/25 Conflict: fresh thyme
          Value 'fresh thyme' exists as alias on Mealie item 'thyme'
          But 'thyme' was already claimed by import item 'dried thyme'
          Fix: Remove 'fresh thyme' from 'thyme' aliases in Mealie

═══════════════════════════════════════════
 Foods Import Summary (WhatIf)
═══════════════════════════════════════════
  Created         : 2
  Updated         : 1
  Unchanged       : 20
  Conflicts       : 2
───────────────────────────────────────────
  Total processed : 25
```

This typically happens when splitting ingredients (e.g., separating "thyme" into "fresh thyme" and "dried thyme") while the original still has aliases pointing to both versions.

### Pre-Import Conflict Detection

MealieSync automatically detects duplicate items **within files** and **across files** before import. This catches common issues like:
- Same ingredient in multiple category files
- Aliases conflicting with names in other items
- Duplicate entries within a single file

**Automatic checking** — Conflict detection runs automatically when you use `Invoke-MealieSync.ps1`:

```powershell
# Single file: checks for within-file conflicts
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting -WhatIf

# Folder: checks both within-file AND cross-file conflicts
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\nl\Foods -UpdateExisting -WhatIf
```

```
Importing Foods from: .\Data\nl\Foods
Folder Import: 28 JSON file(s) found
Checking for conflicts...

═══════════════════════════════════════════
 Food Conflicts
═══════════════════════════════════════════

── Within-File Conflicts (1) ──

CONFLICT 1: "kleefrijst"
  ├─ pasta_rijst_noedels.json:alias of "sushirijst"
  ├─ pasta_rijst_noedels.json:name of "kleefrijst"
  └─ pasta_rijst_noedels.json:pluralName of "kleefrijst"

── Cross-File Conflicts (2) ──

CONFLICT 2: "doperwt"
  ├─ groente.json:      name of "doperwt"
  └─ peulvruchten.json: name of "doperwt"

CONFLICT 3: "dragon"
  ├─ kruiden.json:      name of "dragon"
  └─ groente.json:      alias of "dragon (gedroogd)"

───────────────────────────────────────────
  Conflicts found : 3 (1 within-file, 2 cross-file)
  Files scanned   : 28
  Items scanned   : 1222

Error: Import aborted: 3 conflict(s) found. Fix conflicts before importing.
```

If conflicts are found, the entire operation is blocked until you fix them. When no conflicts exist:

```
Checking for conflicts...
  No conflicts found
```

**Manual checking** — For scripted use or checking without importing:

```powershell
# Check a folder
Test-MealieFoodConflicts -Folder .\Foods

# Check specific files
Test-MealieFoodConflicts -Path @("Groente.json", "Fruit.json")

# Quiet mode for scripts (returns result object only)
$result = Test-MealieFoodConflicts -Folder .\Foods -Quiet
if ($result.HasConflicts) {
    Write-Error "Found $($result.ConflictCount) conflicts"
}
```

### Understanding the Output

MealieSync uses colors to help you quickly scan results:

| Color          | Meaning                            |
| -------------- | ---------------------------------- |
| 🟢 **Green**    | Success, new values, created items |
| 🟡 **Yellow**   | Warnings, updates, matched items   |
| 🔴 **Red**      | Errors, conflicts, blocking issues |
| ⬛ **Gray**     | Skipped, unchanged, old values     |
| 🔵 **Cyan**     | Headers, item names, structure     |
| 🟤 **Dark Red** | Destructive actions (deletions)    |

In change displays, old values appear in gray and new values in green:
```
description : 'old value' → 'new value'
              ↑ gray        ↑ green
```

### Import

```powershell
# Import new items only (skip existing)
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json

# Import and update existing items
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting

# Import all JSON files from a folder
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\nl\Foods -UpdateExisting

# Import only items with a specific label
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -Label "Vegetables"

# Replace aliases instead of merging
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting -ReplaceAliases
```

### Export

```powershell
# Export all foods to a single file
.\Invoke-MealieSync.ps1 -Action Export -Type Foods -JsonPath .\Exports\Foods.json

# Export only foods with a specific label
.\Invoke-MealieSync.ps1 -Action Export -Type Foods -JsonPath .\Exports\Vegetables.json -Label "Vegetables"

# Split by label (one file per category)
.\Invoke-MealieSync.ps1 -Action Export -Type Foods -Folder .\Exports\ByLabel -SplitByLabel
```

Split export creates organized files:

```
Exports/ByLabel/
├── Vegetables.json      (100 foods)
├── Fruit.json           (81 foods)
├── Meat.json            (80 foods)
├── Herbs & Spices.json  (88 foods)
├── ...
└── _No_Label.json       (22 foods)

Total: 1074 foods in 29 files
```

### Mirror (Full Sync)

> ⚠️ **Mirror will DELETE items** from Mealie that aren't in your JSON file!

```powershell
# Always preview first
.\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -JsonPath .\Foods.json -WhatIf

# Sync with confirmation prompt
.\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -JsonPath .\Foods.json

# Scope deletions to a specific label (safer)
.\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -JsonPath .\Vegetables.json -Label "Vegetables"
```

Mirror shows a preview and asks for confirmation:

```
╔═══════════════════════════════════════════════════════════════╗
║  SYNC MODE - This will ADD, UPDATE, and DELETE foods          ║
║  Label scope: Vegetables                                      ║
║  (Only 'Vegetables' items will be deleted)                    ║
╚═══════════════════════════════════════════════════════════════╝

Backup created: .\Exports\AutoBackups\Backup_Foods_20260107_111820.json

═══════════════════════════════════════════════════════════════
 Mirror Preview - Foods
═══════════════════════════════════════════════════════════════

 Phase 1 - Import:
   Create  : 5
   Update  : 12
   Skip    : 83

 Phase 2 - Delete:
   Delete  : 2 items

═══════════════════════════════════════════════════════════════

Continue with 19 change(s)? [Y/N]:
```

Mirror also protects items used in recipes:

```
  ⚠️  Cannot delete items that are used in recipes:

      • shatkora (used in 2 recipes)

      Remove these items from recipes first, or add them to
      your JSON file to keep them in Mealie.
```

---

## Utility Tools

Located in the `Tools/` folder:

### Show-MealieStats.ps1

Dashboard showing your Mealie data at a glance:

```powershell
.\Tools\Show-MealieStats.ps1
```

```
----------------------------------------
  FOODS BY LABEL
----------------------------------------

  Groente                  100  ████ 9.3%
  Kruiden & Specerijen      88  ████ 8.2%
  Fruit                     81  ███ 7.5%
  Vlees                     80  ███ 7.4%
  Vis & Zeevruchten         67  ███ 6.2%
  ...

----------------------------------------
  ALIASES
----------------------------------------

  Foods with aliases:  619
  Total aliases:       1009
  Avg aliases/food:    0.94
```

### Backup-MealieData.ps1

Create timestamped backups of all your data:

```powershell
.\Tools\Backup-MealieData.ps1
```

```
BACKUP SUMMARY

  Successful: 6 files
  Total items: 1525
  Total size:  392 KB

Files created:
  - Foods.json (1074 items)
  - Units.json (48 items)
  - Labels.json (29 items)
  - Categories.json (21 items)
  - Tags.json (232 items)
  - Tools.json (121 items)
```

### Test-MealieConnection.ps1

Verify your setup is working:

```powershell
.\Tools\Test-MealieConnection.ps1 -Detailed
```

### Convert-MealieSyncJson.ps1

Migrate legacy JSON files (raw arrays) to the new wrapper format:

```powershell
# Convert a single file
.\Tools\Convert-MealieSyncJson.ps1 -Path .\Foods.json -Type Foods

# Convert all files in a folder
.\Tools\Convert-MealieSyncJson.ps1 -Folder .\Data\Labels -Type Foods

# Preview without making changes
.\Tools\Convert-MealieSyncJson.ps1 -Path .\Foods.json -Type Foods -WhatIf
```

---

## Parameter Reference

| Parameter         | Actions                | Description                                                      |
| ----------------- | ---------------------- | ---------------------------------------------------------------- |
| `-Type`           | All                    | Data type: Foods, Units, Labels, Categories, Tags, Tools         |
| `-JsonPath`       | Export, Import, Mirror | Path to JSON file                                                |
| `-Folder`         | Import, Export         | Path to folder (Import: read all JSON; Export: split output)     |
| `-Label`          | Export, Import, Mirror | Filter by label. For Mirror, scopes deletions to that label only |
| `-SplitByLabel`   | Export (Foods)         | Create separate file per label                                   |
| `-UpdateExisting` | Import                 | Update existing items (default: skip)                            |
| `-ReplaceAliases` | Import, Mirror         | Replace aliases instead of merging                               |
| `-SkipBackup`     | Import, Mirror         | Don't create automatic backup                                    |
| `-Force`          | Mirror                 | Skip preview and confirmation prompt                             |
| `-WhatIf`         | All                    | Preview without making changes                                   |

---

## JSON Format

All JSON files use a wrapper format with metadata for validation:

```json
{
  "$schema": "mealie-sync",
  "$type": "Foods",
  "$version": "1.0",
  "items": [
    {
      "id": "b9dc4c47-c569-4630-846f-1f4b4fbda3c1",
      "name": "sour cream",
      "pluralName": "sour cream",
      "description": "Cultured cream; topping for tacos or soups.",
      "aliases": [
        { "name": "crème fraîche" },
        { "name": "schmand" }
      ],
      "label": "Dairy",
      "householdsWithIngredientFood": ["main-household"]
    }
  ]
}
```

<details>
<summary><strong>All JSON schemas with field details</strong></summary>

### Food

| Field                          | Required | Description                                        |
| ------------------------------ | :------: | -------------------------------------------------- |
| `id`                           |    —     | UUID (auto-generated if missing)                   |
| `name`                         |    ✅     | Primary name (singular)                            |
| `pluralName`                   |    —     | Plural form                                        |
| `description`                  |    —     | Short description                                  |
| `aliases`                      |    —     | Array of `{ "name": "..." }` objects               |
| `label`                        |    —     | Category label name                                |
| `householdsWithIngredientFood` |    —     | Array of household names that have this ingredient |

```json
{
  "$schema": "mealie-sync",
  "$type": "Foods",
  "$version": "1.0",
  "items": [
    {
      "id": "uuid",
      "name": "tomato",
      "pluralName": "tomatoes",
      "description": "Description text",
      "aliases": [{ "name": "alias" }],
      "label": "Vegetables",
      "householdsWithIngredientFood": ["household-name"]
    }
  ]
}
```

### Unit

| Field                | Required | Description                      |
| -------------------- | :------: | -------------------------------- |
| `id`                 |    —     | UUID (auto-generated if missing) |
| `name`               |    ✅     | Primary name (singular)          |
| `pluralName`         |    —     | Plural form                      |
| `description`        |    —     | Description (e.g., "15 ml")      |
| `abbreviation`       |    —     | Short form (e.g., "tbsp")        |
| `pluralAbbreviation` |    —     | Plural short form                |
| `useAbbreviation`    |    —     | Show abbreviation in recipes     |
| `fraction`           |    —     | Allow fractional values          |
| `aliases`            |    —     | Alternative names                |

```json
{
  "$schema": "mealie-sync",
  "$type": "Units",
  "$version": "1.0",
  "items": [
    {
      "id": "uuid",
      "name": "tablespoon",
      "pluralName": "tablespoons",
      "description": "15 ml",
      "abbreviation": "tbsp",
      "pluralAbbreviation": "tbsp",
      "useAbbreviation": true,
      "fraction": true,
      "aliases": [{ "name": "Tbsp" }]
    }
  ]
}
```

### Label

| Field   | Required | Description                      |
| ------- | :------: | -------------------------------- |
| `id`    |    —     | UUID (auto-generated if missing) |
| `name`  |    ✅     | Label name                       |
| `color` |    —     | Hex color code (e.g., "#4CAF50") |

```json
{
  "$schema": "mealie-sync",
  "$type": "Labels",
  "$version": "1.0",
  "items": [
    {
      "id": "uuid",
      "name": "Vegetables",
      "color": "#4CAF50"
    }
  ]
}
```

### Category / Tag

| Field       | Required | Description                                             |
| ----------- | :------: | ------------------------------------------------------- |
| `id`        |    —     | UUID (auto-generated if missing)                        |
| `name`      |    ✅     | Category or tag name                                    |
| `mergeTags` |    —     | *(Tags only)* Array of tag names to merge into this tag |

```json
{
  "$schema": "mealie-sync",
  "$type": "Categories",
  "$version": "1.0",
  "items": [
    {
      "id": "uuid",
      "name": "Main Course"
    }
  ]
}
```

#### Tag Merge Feature (v2.1.0+)

The `mergeTags` field allows you to consolidate multiple tags into one. When a tag has `mergeTags`:

1. All recipes from source tags receive the target tag
2. Source tags are deleted
3. Normal import/sync continues
```json
{
  "$schema": "mealie-sync",
  "$type": "Tags",
  "$version": "1.0",
  "items": [
    {
      "name": "asian",
      "mergeTags": ["oriental", "indian", "indonesian", "thai"]
    },
    {
      "name": "main-course",
      "mergeTags": ["dinner", "evening-meal"]
    },
    {
      "name": "vegetarian"
    }
  ]
}
```

**Preview merges safely:**
```powershell
.\Invoke-MealieSync.ps1 -Action Import -Type Tags -JsonPath .\Tags.json -WhatIf
```

**Example output:**
```
Connecting to Mealie at: https://mealie.example.com
OK: Connected to Mealie as: User

Importing Tags from: .\Tags.json

Processing tag merges...

═══════════════════════════════════════════
 Tag Merge Preview (WhatIf)
═══════════════════════════════════════════

  Target: asian (exists)
      ← Indian (16 recipes)
      ← Indonesian (3 recipes)
      ← Oriental (1 recipe)
      ← Thai (1 recipe)

  Target: main-course (exists)
      ← Dinner (4 recipes)
      ← Evening-Meal (31 recipes)

───────────────────────────────────────────
  Would merge: 6 source tag(s) affecting ~56 recipe(s)

═══════════════════════════════════════════
 Tags Import Summary (WhatIf)
═══════════════════════════════════════════
  TagsMerged      : 6
───────────────────────────────────────────
  Created         : 0
  Skipped         : 3
───────────────────────────────────────────
  Total processed : 3
```

**Merge Rules:**
| Scenario                         | Result               |
| -------------------------------- | -------------------- |
| Target tag doesn't exist         | ✅ Auto-created       |
| Source tag doesn't exist         | ⚠️ Warning, continues |
| Chained merge (A←B, B←C)         | ❌ Error              |
| Same source for multiple targets | ❌ Error              |

**Error examples:**
```
ERROR: Chained merge detected: 'oriental' is a merge target but is also 
       listed as a source for 'asian'. Chained merges are not supported.

ERROR: Duplicate source: 'oriental' is listed as source for both 
       'international' and 'asian'. A tag can only be merged into one target.
```
> ⚠️ **Important:** Merges execute immediately when found in your JSON—even in Mirror mode, they run before the confirmation prompt. This is by design: `mergeTags` in your JSON is explicit opt-in. Always use `-WhatIf` first to preview merge operations. An automatic backup is created before any changes.

### Tool

| Field                | Required | Description                                  |
| -------------------- | :------: | -------------------------------------------- |
| `id`                 |    —     | UUID (auto-generated if missing)             |
| `name`               |    ✅     | Tool name                                    |
| `householdsWithTool` |    —     | Array of household names that have this tool |

```json
{
  "$schema": "mealie-sync",
  "$type": "Tools",
  "$version": "1.0",
  "items": [
    {
      "id": "uuid",
      "name": "Oven",
      "householdsWithTool": ["household-name"]
    }
  ]
}
```

</details>

---

## Using as a PowerShell Module

For scripting or advanced use cases:

```powershell
Import-Module .\MealieApi.psd1

Initialize-MealieApi -BaseUrl "http://localhost:9000" -Token "your-token"

# CRUD operations
$foods = Get-MealieFoods -All
New-MealieFood -Name "tempeh" -PluralName "tempeh" -Aliases @("tempe")
Update-MealieFood -Id "guid" -Data @{ description = "Fermented soybeans" }
Remove-MealieFood -Id "guid"

# Bulk operations
Export-MealieFoods -Path .\Foods.json
Import-MealieFoods -Path .\Foods.json -UpdateExisting
Sync-MealieFoods -Path .\Foods.json -Force  # Mirror

# Same pattern for Units, Labels, Categories, Tags, Tools
$units = Get-MealieUnits -All
$labels = Get-MealieLabels -All
```

---

## Project Structure

```
MealieSync/
├── Invoke-MealieSync.ps1       # Main CLI interface
├── MealieApi.psd1              # Module manifest
├── MealieApi.psm1              # Module loader
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── LICENSE
│
├── Public/                     # Exported functions (49)
│   ├── Initialize-MealieApi.ps1
│   ├── Foods.ps1               # Get/New/Update/Remove-MealieFood
│   ├── Units.ps1               # Get/New/Update/Remove-MealieUnit
│   ├── Labels.ps1              # Get/New/Update/Remove-MealieLabel
│   ├── Organizers.ps1          # Categories, Tags, Tools
│   ├── Test-Mealie*Conflicts.ps1 # Conflict detection (within/cross-file)
│   ├── Export-*.ps1
│   ├── Import-*.ps1
│   └── Sync-*.ps1
│
├── Private/                    # Internal helpers (61)
│   ├── Invoke-MealieRequest.ps1
│   ├── Compare-Helpers.ps1
│   ├── Validation-Helpers.ps1
│   └── ...
│
├── Tools/                      # Standalone utilities (4)
│   ├── Test-MealieConnection.ps1
│   ├── Show-MealieStats.ps1
│   ├── Backup-MealieData.ps1
│   └── Convert-MealieSyncJson.ps1
│
├── Data/                       # Ingredient data by language
│   ├── README.md               # Contribution guidelines
│   └── nl/                     # Dutch data
│       ├── Foods/              # Split by label
│       ├── Labels.json
│       ├── Units.json
│       └── ...
│
├── docs/                       # Documentation
│   └── COLORS.md               # Console color reference
│
└── Exports/                    # Output folder (gitignored)
    └── AutoBackups/
```

---

## Troubleshooting

<details>
<summary><strong>Execution Policy Error</strong></summary>

```powershell
# Unblock downloaded files
Get-ChildItem -Recurse | Unblock-File

# Or set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

</details>

<details>
<summary><strong>Connection Errors</strong></summary>

Run the diagnostic tool:

```powershell
.\Tools\Test-MealieConnection.ps1 -Detailed
```

Common issues:
- Wrong port number in URL
- Trailing slash in URL (remove it)
- Expired or invalid API token
- Firewall blocking connection

</details>

<details>
<summary><strong>Items Not Updating</strong></summary>

By default, Import skips existing items. Use `-UpdateExisting`:

```powershell
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting
```

</details>

<details>
<summary><strong>Special Characters Garbled</strong></summary>

Ensure JSON files are saved as **UTF-8 without BOM**. The module handles UTF-8 encoding for all API requests.

</details>

<details>
<summary><strong>Import Validation Error</strong></summary>

If you see "Missing type wrapper" or "Type mismatch":
- Ensure your JSON has the wrapper format with `$schema`, `$type`, `$version`
- Check that `$type` matches what you're importing

</details>

---

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Data contributions** (translations, new ingredients) are especially appreciated. See [Data/README.md](Data/README.md) for the data contribution guide.

---

## API Endpoints

| Function   | Method              | Endpoint                                       |
| ---------- | ------------------- | ---------------------------------------------- |
| Foods      | GET/POST/PUT/DELETE | `/api/foods`                                   |
| Units      | GET/POST/PUT/DELETE | `/api/units`                                   |
| Labels     | GET/POST/PUT/DELETE | `/api/groups/labels`                           |
| Categories | GET/POST/PUT/DELETE | `/api/organizers/categories`                   |
| Tags       | GET/POST/PUT/DELETE | `/api/organizers/tags`                         |
| Tools      | GET/POST/PUT/DELETE | `/api/organizers/tools`                        |
| Households | GET                 | `/api/groups/households`                       |
| Recipes    | GET                 | `/api/recipes` (used by Mirror to check usage) |

---

## License

[MIT](LICENSE) — Feel free to use and modify.