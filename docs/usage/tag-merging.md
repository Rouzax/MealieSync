# Tag Merging

MealieSync can consolidate multiple tags into one, automatically transferring all recipe associations before deleting the source tags. This is useful for cleaning up duplicate or overly specific tags.

## How It Works

Add a `mergeTags` field to any tag in your JSON file. When MealieSync processes that tag, it:

1. Assigns the target tag to all recipes that have any of the source tags
2. Deletes the source tags
3. Continues with the normal import/sync

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

## Previewing Merges

Always preview with `-WhatIf` first:

```powershell
.\Invoke-MealieSync.ps1 -Action Import -Type Tags -JsonPath .\Tags.json -WhatIf
```

```
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
```

## Rules and Error Handling

| Scenario                         | Result                |
| -------------------------------- | --------------------- |
| Target tag does not exist        | Auto-created          |
| Source tag does not exist        | Warning, continues    |
| Chained merge (A←B, B←C)        | Error, blocks import  |
| Same source for multiple targets | Error, blocks import  |

**Error examples:**

```
ERROR: Chained merge detected: 'oriental' is a merge target but is also
       listed as a source for 'asian'. Chained merges are not supported.

ERROR: Duplicate source: 'oriental' is listed as source for both
       'international' and 'asian'. A tag can only be merged into one target.
```

!!! warning
    Merges execute immediately when found in your JSON, even in Mirror mode. They run before the Mirror confirmation prompt. This is by design: `mergeTags` in your JSON is explicit opt-in. Always use `-WhatIf` first to preview merge operations. An automatic backup is created before any changes.

## Works with Both Import and Mirror

Tag merging runs during both Import and Mirror operations. The merge phase always happens first, before the regular import/sync phase.
