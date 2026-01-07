# Dutch (Nederlands) Data

This folder contains Dutch ingredient data for Mealie.

## Contents

| File              | Description                        | Items |
| ----------------- | ---------------------------------- | ----- |
| `RULES.md`        | Regels en richtlijnen (Nederlands) | -     |
| `Labels.json`     | Food categories                    | 29    |
| `Units.json`      | Measurement units                  | 48    |
| `Categories.json` | Recipe categories                  | 21    |
| `Tags.json`       | Recipe tags                        | -     |
| `Tools.json`      | Kitchen equipment                  | 121   |
| `Foods/`          | Ingredients by label               | 1000+ |

## Import Order

```powershell
# From MealieSync root folder:

# 1. Labels first
.\Invoke-MealieSync.ps1 -Action Import -Type Labels -JsonPath .\Data\nl\Labels.json

# 2. Units
.\Invoke-MealieSync.ps1 -Action Import -Type Units -JsonPath .\Data\nl\Units.json

# 3. Foods (references labels)
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\nl\Foods

# 4. Recipe organizers
.\Invoke-MealieSync.ps1 -Action Import -Type Categories -JsonPath .\Data\nl\Categories.json
.\Invoke-MealieSync.ps1 -Action Import -Type Tools -JsonPath .\Data\nl\Tools.json
```

## Data Guidelines

See [RULES.md](RULES.md) for Dutch-specific naming and categorization rules.

Key principles:
- Primary names are singular Dutch terms
- Labels categorize by what ingredients ARE, not cuisine origin
- Aliases are true synonyms only (not varieties or preparations)
- Fresh vs. dried, whole vs. ground are separate ingredients
