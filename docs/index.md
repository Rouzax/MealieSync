# MealieSync

A PowerShell toolkit for managing [Mealie](https://mealie.io) recipe data via REST API. Import, export, and synchronize your ingredients, units, labels, and more, with smart duplicate prevention, change detection, and full bidirectional sync.

```
============================================================
           MEALIE STATISTICS DASHBOARD
============================================================

  Foods         1312        Categories      22
  Units           48        Tags            50
  Labels          29        Tools          121
                            ─────────────────
                            Total:        1582
```

## Why MealieSync?

Mealie's web interface is great for individual edits, but managing hundreds of ingredients or performing bulk updates becomes tedious. MealieSync gives you:

- **Offline editing.** Work on JSON files in your favorite editor, then sync
- **Version control.** Track changes to your ingredient database with Git
- **Bulk operations.** Import entire databases at once
- **AI-friendly.** Use LLMs to generate, translate, or expand ingredient data, then import directly
- **Duplicate prevention.** Smart matching across names, plurals, and aliases
- **Conflict detection.** Catch duplicates within and across JSON files before import
- **Safe previews.** See exactly what will change before committing
- **Full sync.** Mirror your JSON to Mealie exactly, including deletions
- **Tag consolidation.** Merge multiple tags into one, automatically updating all affected recipes

## Included Data

This repository includes ingredient databases ready to import:

| Language | Code | Status                                       |
| -------- | ---- | -------------------------------------------- |
| Dutch    | `nl` | 1,312 ingredients, actively maintained       |
| French   | `fr` | 1,311 ingredients                            |
| English  | `en` | Open to contributions                        |
| German   | `de` | Open to contributions                        |
| *Other*  | ---  | [Contribute yours!](contributing/data-guide.md) |

Food items share stable UUIDs across languages, so the Dutch "aardappel" and French "pomme de terre" are linked by the same identifier. See the [data contribution guide](contributing/data-guide.md) for details.

## Next Steps

- [Getting Started](getting-started.md): install, configure, and run your first import
- [Usage Guide](usage/overview.md): learn the core concepts and operations
- [Parameter Reference](reference/parameters.md): all available options

## Related

- [MealieRecipeParser](https://github.com/Rouzax/MealieRecipeParser): a ChatGPT Project that converts recipes from photos, URLs, or text into schema.org/Recipe JSON-LD for Mealie import
