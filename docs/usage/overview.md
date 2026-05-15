# Usage Overview

All operations go through a single entry point:

```powershell
.\Invoke-MealieSync.ps1 -Action <action> -Type <type> [options]
```

## Actions

| Action   | Description                                                  |
| -------- | ------------------------------------------------------------ |
| `List`   | Display items currently in Mealie                            |
| `Export` | Save items from Mealie to JSON files                         |
| `Import` | Add items from JSON, optionally updating existing ones       |
| `Mirror` | Full sync: add, update, **and delete** to match JSON exactly |

## Data Types

| Type         | Description                         | Examples                    |
| ------------ | ----------------------------------- | --------------------------- |
| `Foods`      | Ingredients with aliases and labels | tomato, garlic, soy sauce   |
| `Units`      | Measurements with abbreviations     | tablespoon (tbsp), gram (g) |
| `Labels`     | Color-coded food categories         | Vegetables, Meat, Dairy     |
| `Categories` | Recipe categories                   | Main course, Appetizer      |
| `Tags`       | Recipe tags                         | Vegetarian, Quick meals     |
| `Tools`      | Kitchen equipment                   | Oven, Wok, Blender          |

## Smart Matching

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

1. **ID.** Exact UUID match (highest priority, safest for renames)
2. **Name to Name.** Direct name match
3. **Name to PluralName.** Cross-match (e.g., importing "tomatoes" finds existing "tomato")
4. **Name to Alias.** Import name matches an existing item's alias
5. **Alias to Name.** Import alias matches an existing item's name

This ensures that renaming an ingredient (with the same ID) works correctly, and that items are not duplicated even if the name/plural relationship is reversed.

## Understanding the Output

MealieSync uses colors to help you quickly scan results:

| Color          | Meaning                            |
| -------------- | ---------------------------------- |
| Green          | Success, new values, created items |
| Yellow         | Warnings, updates, matched items   |
| Red            | Errors, conflicts, blocking issues |
| Gray           | Skipped, unchanged, old values     |
| Cyan           | Headers, item names, structure     |
| Dark Red       | Destructive actions (deletions)    |

In change displays, old values appear in gray and new values in green:
```
description : 'old value' → 'new value'
              ↑ gray        ↑ green
```

## Listing Items

The simplest way to see what is in your Mealie instance:

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

```powershell
.\Invoke-MealieSync.ps1 -Action List -Type Foods
```

```
name                            pluralName                      label
----                            ----------                      -----
aalbes                          aalbessen                       Fruit
aardappel                       aardappelen                     Aardappelen & Knollen
aardappelzetmeel                aardappelzetmeel                Bakproducten
aardbei                         aardbeien                       Fruit
...

Total: 1312 foods
```
