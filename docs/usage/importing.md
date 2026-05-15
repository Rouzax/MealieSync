# Importing

Import adds items from JSON files into Mealie. By default, existing items are skipped. Use `-UpdateExisting` to update them.

## Basic Import

```powershell
# Import new items only (skip existing)
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json

# Import and update existing items
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting

# Import all JSON files from a folder
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\nl\Foods -UpdateExisting

# Import only items with a specific label
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -Label "Vegetables"
```

## Alias Handling

By default, importing merges aliases: new aliases from your JSON are added to the existing ones in Mealie. To replace aliases entirely instead of merging, use `-ReplaceAliases`:

```powershell
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting -ReplaceAliases
```

## Previewing Changes

Always preview before importing with `-WhatIf`:

```powershell
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting -WhatIf
```

```
Import mode:
  [X] Update existing items
  [ ] Replace aliases (merge mode, use -ReplaceAliases to replace)

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

## Conflict Detection

MealieSync detects conflicts where an item cannot be cleanly matched. This happens when an import item's name or alias collides with an existing Mealie item that was already claimed by a different import item:

```
   9/25 Conflict: fresh dill
          Value 'fresh dill' exists as alias on Mealie item 'dill'
          But 'dill' was already claimed by import item 'dried dill'
          Fix: Remove 'fresh dill' from 'dill' aliases in Mealie

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

## Pre-Import Conflict Detection

MealieSync automatically detects duplicate items **within files** and **across files** before import. This catches common issues like:

- Same ingredient appearing in multiple category files
- Aliases conflicting with names in other items
- Duplicate entries within a single file

When importing from a folder, both within-file and cross-file checks run automatically:

```powershell
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\nl\Foods -UpdateExisting -WhatIf
```

```
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

If conflicts are found, the entire operation is blocked until you fix them.

### Manual Conflict Checking

You can also run conflict checks without importing, useful for scripted workflows:

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

## Food UUIDs and Multi-Group Servers

The included datasets contain stable UUIDs for each food, shared across language variants (so Dutch "aardappel" and French "pomme de terre" have the same ID). When importing to a fresh Mealie instance, these UUIDs are preserved.

If you import the same dataset into a second group on the same Mealie server, the UUIDs will collide because all groups share one database. MealieSync detects this automatically, switches to importing without UUIDs, and shows a message. All foods are still created successfully; only the cross-language UUID linking is lost for that import.

## Backups

An automatic backup is created before any import. Use `-SkipBackup` to disable this.
