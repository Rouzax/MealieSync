# Getting Started

## Requirements

- **PowerShell 7.0+** ([Download here](https://github.com/PowerShell/PowerShell/releases))
- **Mealie v2.x** with API access
- **API token** from your Mealie user profile

!!! warning
    Windows PowerShell 5.1 is not supported due to UTF-8 encoding limitations. You need PowerShell 7.0 or later.

## Install

```powershell
# Clone the repository
git clone https://github.com/Rouzax/MealieSync.git
cd MealieSync

# On Windows: unblock downloaded files
Get-ChildItem -Recurse | Unblock-File
```

## Configure

Create `mealie-config.json` in the project root:

```json
{
  "BaseUrl": "http://your-mealie-server:9000",
  "Token": "your-api-token-here"
}
```

To get your API token, go to **Mealie > Profile > Manage Your API Tokens**.

You can also point to a config file in a different location using the `-ConfigPath` parameter on any command.

## Test Your Connection

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
  [✓] Foods - 1312 items
  [✓] Units - 48 items
  [✓] Labels - 29 items
  [✓] Categories - 22 items
  [✓] Tags - 50 items
  [✓] Tools - 121 items
  [✓] Households - 1 items

==================================================
  All tests passed! Connection is working.
```

If the test fails, see [Troubleshooting](troubleshooting.md).

## Your First Import

Import operations have a recommended order because some types reference others. Labels should be imported before Foods, since each food can be assigned to a label.

```powershell
# Import labels first (foods reference them)
.\Invoke-MealieSync.ps1 -Action Import -Type Labels -JsonPath .\Data\nl\Labels.json

# Import foods (from folder containing all category files)
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\nl\Foods

# Import the rest (no particular order needed)
.\Invoke-MealieSync.ps1 -Action Import -Type Units -JsonPath .\Data\nl\Units.json
.\Invoke-MealieSync.ps1 -Action Import -Type Tools -JsonPath .\Data\nl\Tools.json
.\Invoke-MealieSync.ps1 -Action Import -Type Categories -JsonPath .\Data\nl\Categories.json
.\Invoke-MealieSync.ps1 -Action Import -Type Tags -JsonPath .\Data\nl\Tags.json
```

!!! tip
    Add `-WhatIf` to any command to preview what would happen without making changes. This is especially useful before your first import to verify everything looks correct.

## What's Next?

- [Usage overview](usage/overview.md): understand actions, data types, and how smart matching works
- [Importing](usage/importing.md): import options, update modes, and conflict detection
- [Mirroring](usage/mirroring.md): full bidirectional sync with deletion support
