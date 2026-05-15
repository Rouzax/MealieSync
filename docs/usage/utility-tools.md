# Utility Tools

The `Tools/` folder contains standalone scripts for common tasks.

## Show-MealieStats.ps1

Dashboard showing your Mealie data at a glance:

```powershell
.\Tools\Show-MealieStats.ps1
```

```
============================================================
           MEALIE STATISTICS DASHBOARD
============================================================

  SUMMARY
----------------------------------------
  Foods         1312
  Units           48
  Labels          29
  Categories      22
  Tags            50
  Tools          121

  Total items:  1582

----------------------------------------
  FOODS BY LABEL
----------------------------------------

  Kruiden & Specerijen     105  ████ 8%
  Groente                  101  ███ 7.7%
  Fruit                     96  ███ 7.3%
  Vlees                     84  ███ 6.4%
  Vis & Zeevruchten         75  ██ 5.7%
  Sauzen & Condimenten      73  ██ 5.6%
  Bakproducten              68  ██ 5.2%
  Wijn                      66  ██ 5%
  Pasta, Rijst & Noedels    64  ██ 4.9%
  Kaas                      63  ██ 4.8%
  ...

----------------------------------------
  ALIASES
----------------------------------------

  Foods with aliases:  938
  Total aliases:       2232
  Avg aliases/food:    1.7

  Units with aliases:  41
  Total unit aliases:  91
```

## Backup-MealieData.ps1

Create timestamped backups of all your data:

```powershell
.\Tools\Backup-MealieData.ps1
```

```
BACKUP SUMMARY

  Successful: 6 files
  Total items: 1582
  Total size:  392 KB

Files created:
  - Foods.json (1312 items)
  - Units.json (48 items)
  - Labels.json (29 items)
  - Categories.json (22 items)
  - Tags.json (50 items)
  - Tools.json (121 items)
```

## Test-MealieConnection.ps1

Verify your setup is working. Checks the module, config file, network connectivity, authentication, and all API endpoints:

```powershell
.\Tools\Test-MealieConnection.ps1 -Detailed
```

See [Getting Started](../getting-started.md) for the full output example.

## Convert-MealieSyncJson.ps1

Migrate legacy JSON files (raw arrays without the wrapper format) to the current format:

```powershell
# Convert a single file
.\Tools\Convert-MealieSyncJson.ps1 -Path .\Foods.json -Type Foods

# Convert all files in a folder
.\Tools\Convert-MealieSyncJson.ps1 -Folder .\Data\Labels -Type Foods

# Preview without making changes
.\Tools\Convert-MealieSyncJson.ps1 -Path .\Foods.json -Type Foods -WhatIf
```

See [JSON Format](../reference/json-format.md) for details on the wrapper format.
