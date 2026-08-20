# MealieSync

[![PowerShell 7.0+](https://img.shields.io/badge/PowerShell-7.0%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Mealie v2.x](https://img.shields.io/badge/Mealie-v2.x-green.svg)](https://mealie.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Docs](https://img.shields.io/badge/docs-rouzax.github.io%2FMealieSync-blue)](https://rouzax.github.io/MealieSync)
[![Support on Ko-fi](https://img.shields.io/badge/Ko--fi-Support-FF5E5B?logo=kofi&logoColor=white)](https://ko-fi.com/O0W221GBUG)

A PowerShell toolkit for managing [Mealie](https://mealie.io) recipe data via REST API. Import, export, and synchronize your ingredients, units, labels, and more, with smart duplicate prevention, change detection, and full bidirectional sync.

## Why MealieSync?

Mealie's web interface is great for individual edits, but managing hundreds of ingredients or performing bulk updates becomes tedious. MealieSync gives you:

- **Offline editing.** Work on JSON files in your favorite editor, then sync
- **Version control.** Track changes to your ingredient database with Git
- **Bulk operations.** Import entire databases at once
- **Duplicate prevention.** Smart matching across names, plurals, and aliases
- **Safe previews.** See exactly what will change before committing
- **Full sync.** Mirror your JSON to Mealie exactly, including deletions

## Included Data

| Language | Code | Status                                    |
| -------- | ---- | ----------------------------------------- |
| Dutch    | `nl` | 1,312 ingredients, actively maintained    |
| French   | `fr` | 1,311 ingredients                         |
| English  | `en` | Open to contributions                     |
| German   | `de` | Open to contributions                     |
| *Other*  | ---  | [Contribute yours!](Data/README.md)       |

Food items share stable UUIDs across languages, so the Dutch "aardappel" and French "pomme de terre" are linked by the same identifier.

## Quick Start

### Requirements

- **PowerShell 7.0+** ([Download here](https://github.com/PowerShell/PowerShell/releases))
- **Mealie v2.x** with API access
- **API token** from your Mealie user profile

### Install and Configure

```powershell
git clone https://github.com/Rouzax/MealieSync.git
cd MealieSync

# On Windows: unblock downloaded files
Get-ChildItem -Recurse | Unblock-File

# Create your config from the sample
Copy-Item mealie-config-sample.json mealie-config.json
```

Edit `mealie-config.json` with your Mealie URL and API token:

```json
{
  "BaseUrl": "http://your-mealie-server:9000",
  "Token": "your-api-token-here"
}
```

To get your API token, go to **Mealie > Profile > Manage Your API Tokens**.

### Test and Import

```powershell
# Test your connection
.\Tools\Test-MealieConnection.ps1 -Detailed

# Import the Dutch dataset (labels first, since foods reference them)
.\Invoke-MealieSync.ps1 -Action Import -Type Labels -JsonPath .\Data\nl\Labels.json
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\nl\Foods
.\Invoke-MealieSync.ps1 -Action Import -Type Units -JsonPath .\Data\nl\Units.json
.\Invoke-MealieSync.ps1 -Action Import -Type Tools -JsonPath .\Data\nl\Tools.json
.\Invoke-MealieSync.ps1 -Action Import -Type Categories -JsonPath .\Data\nl\Categories.json
.\Invoke-MealieSync.ps1 -Action Import -Type Tags -JsonPath .\Data\nl\Tags.json
```

## See It in Action

Preview what an import would do without making any changes:

```powershell
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Data\nl\Foods\groente.json -UpdateExisting -WhatIf
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

═══════════════════════════════════════════
 Foods Import Summary (WhatIf)
═══════════════════════════════════════════
  Updated         : 2
  Unchanged       : 16
───────────────────────────────────────────
  Total processed : 18
```

## Utility Tools

| Tool | Description |
| ---- | ----------- |
| `Tools\Show-MealieStats.ps1` | Dashboard with item counts, label distribution, and alias stats |
| `Tools\Backup-MealieData.ps1` | Create timestamped backups of all data |
| `Tools\Test-MealieConnection.ps1` | Verify connection, authentication, and API access |
| `Tools\Convert-MealieSyncJson.ps1` | Migrate legacy JSON files to the current format |

## Documentation

Full documentation is available at **[rouzax.github.io/MealieSync](https://rouzax.github.io/MealieSync)**.

- [Getting Started](https://rouzax.github.io/MealieSync/getting-started/)
- [Usage Guide](https://rouzax.github.io/MealieSync/usage/overview/)
- [Parameter Reference](https://rouzax.github.io/MealieSync/reference/parameters/)
- [JSON Format](https://rouzax.github.io/MealieSync/reference/json-format/)
- [Troubleshooting](https://rouzax.github.io/MealieSync/troubleshooting/)

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Data contributions** (translations, new ingredients) are especially appreciated. See [Data/README.md](Data/README.md) for the data contribution guide.

## Related

- [MealieRecipeParser](https://github.com/Rouzax/MealieRecipeParser): a ChatGPT Project that converts recipes from photos, URLs, or text into schema.org/Recipe JSON-LD for Mealie import

## Contributors

| Who | Contribution |
| --- | --- |
| [@Rouzax](https://github.com/Rouzax) | Author, Dutch dataset, core module |
| [@sochartgit](https://github.com/sochartgit) | French dataset ([#1](https://github.com/Rouzax/MealieSync/issues/1)) |

## Support

Building tools that solve my own problems and sharing them in the hope they solve yours too. If MealieSync saved you from retyping a thousand ingredients into a web form one at a time, a coffee is always welcome.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/O0W221GBUG)

## License

[MIT](LICENSE)
