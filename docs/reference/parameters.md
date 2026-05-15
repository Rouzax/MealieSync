# Parameter Reference

All parameters for `Invoke-MealieSync.ps1`.

## Required Parameters

| Parameter | Description                                                          |
| --------- | -------------------------------------------------------------------- |
| `-Action` | Operation to perform: `Import`, `Export`, `List`, or `Mirror`        |
| `-Type`   | Data type: `Foods`, `Units`, `Labels`, `Categories`, `Tags`, `Tools` |

## Data Source Parameters

| Parameter  | Actions                | Description                                                  |
| ---------- | ---------------------- | ------------------------------------------------------------ |
| `-JsonPath`| Export, Import, Mirror | Path to a JSON file                                          |
| `-Folder`  | Import, Export, Mirror | Path to a folder. Import/Mirror: reads all JSON files in the folder. Export: output directory for split export. |

You must provide either `-JsonPath` or `-Folder` for Export, Import, and Mirror actions.

## Filter Parameters

| Parameter      | Actions          | Description                                                              |
| -------------- | ---------------- | ------------------------------------------------------------------------ |
| `-Label`       | Export, Import, Mirror | Filter by label name. For Mirror, scopes deletions to that label only. |
| `-SplitByLabel`| Export (Foods only) | Create one output file per label instead of a single file.             |

## Behavior Parameters

| Parameter         | Actions        | Description                                            |
| ----------------- | -------------- | ------------------------------------------------------ |
| `-UpdateExisting` | Import, Mirror | Update existing items instead of skipping them         |
| `-ReplaceAliases` | Import, Mirror | Replace aliases instead of merging new ones in         |
| `-SkipBackup`     | Import, Mirror | Skip the automatic pre-operation backup                |
| `-Force`          | Mirror         | Skip the confirmation prompt before making changes     |

## Global Parameters

| Parameter     | Actions | Description                                                         |
| ------------- | ------- | ------------------------------------------------------------------- |
| `-ConfigPath` | All     | Path to config file. Defaults to `.\mealie-config.json`             |
| `-WhatIf`     | All     | Preview what would happen without making any changes                |
| `-Confirm`    | All     | Prompt for confirmation before each change (PowerShell built-in)    |

## Common Combinations

```powershell
# Preview a full import with updates
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\nl\Foods -UpdateExisting -WhatIf

# Mirror a single label safely
.\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -JsonPath .\Vegetables.json -Label "Vegetables" -WhatIf

# Export split by label
.\Invoke-MealieSync.ps1 -Action Export -Type Foods -Folder .\Exports -SplitByLabel

# Use a different config file
.\Invoke-MealieSync.ps1 -Action List -Type Foods -ConfigPath .\other-config.json
```
