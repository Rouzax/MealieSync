# Mirroring

Mirror is a full bidirectional sync: it adds missing items, updates changed items, and **deletes items from Mealie that are not in your JSON**. This makes your JSON files the single source of truth.

!!! warning
    Mirror will delete items from Mealie that are not in your JSON file. Always preview with `-WhatIf` first.

## Basic Usage

```powershell
# Always preview first
.\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -JsonPath .\Foods.json -WhatIf

# Run the sync (will show a confirmation prompt before making changes)
.\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -JsonPath .\Foods.json

# Mirror from a folder of JSON files
.\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -Folder .\Data\nl\Foods
```

## How It Works

Mirror runs in two phases:

1. **Phase 1: Import.** Adds new items and updates existing ones (same as Import with `-UpdateExisting`)
2. **Phase 2: Delete.** Finds items in Mealie that are not in your JSON and removes them

Before executing, Mirror shows a preview and asks for confirmation:

```
Mirroring Labels to match: .\Data\nl\Labels.json

═══════════════════════════════════════════════════════════════
 MIRROR MODE - This will ADD, UPDATE, and DELETE labels
 WARNING: Deleting labels removes them from all foods!
═══════════════════════════════════════════════════════════════

Phase 1: Importing (add/update)...

═══════════════════════════════════════════
 Labels Import Summary (WhatIf)
═══════════════════════════════════════════
  Unchanged       : 29
───────────────────────────────────────────
  Total processed : 29

Phase 2: Finding orphaned items...
  No orphaned items to delete.
```

## Mirroring from a Folder

When you use `-Folder`, all JSON files in the folder are treated as one combined dataset. MealieSync imports each file individually (so you can see which file contributes which changes), then runs a single delete pass comparing Mealie against all files combined. An item that exists in any file is kept; only items not found in any file are deleted.

```powershell
# Preview folder mirror
.\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -Folder .\Data\nl\Foods -WhatIf

# Run folder mirror
.\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -Folder .\Data\nl\Foods
```

Cross-file conflict detection runs automatically before any changes. If two files define the same item, the operation is blocked until you fix the conflict.

Folder mirror is supported for Foods and Units. For other types, use `-JsonPath` with a single file.

## Scoping Deletions with Labels

You can scope Mirror to a specific label. This limits deletions to items with that label only, leaving everything else untouched:

```powershell
.\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -JsonPath .\Vegetables.json -Label "Vegetables"
```

This is safer than a full mirror when you only manage a subset of your data through MealieSync.

## Recipe Protection

When mirroring Foods, MealieSync checks whether items scheduled for deletion are used in any recipes. Items that are in use are protected from deletion:

```
Analyzing changes...
  Checking recipe usage for 4 item(s) to delete...

  Cannot delete items that are used in recipes:

      spinach [fresh] (used in 1 recipe)
      dried chili pepper (used in 1 recipe)
      marinated jalapeño (used in 1 recipe)
      mushroom (used in 1 recipe)

      Remove these items from recipes first, or add them to
      your JSON file to keep them in Mealie.
```

## Skipping Confirmation

Use `-Force` to skip the confirmation prompt. This is useful for automated workflows, but be careful:

```powershell
.\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -JsonPath .\Foods.json -Force
```

## Backups

An automatic backup is created before any mirror operation. Use `-SkipBackup` to disable this.
