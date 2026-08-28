# English (EN) Data

This folder contains English ingredient data for Mealie, translated, adapted, and strictly mapped from the foundational Dutch (NL) dataset.

## Contents

| File              | Description                        | Items |
| ----------------- | ---------------------------------- | ----- |
| `EN_FOOD_RULES.md`| Rules and guidelines (English)     | -     |
| `Labels.json`     | Food categories                    | 29    |
| `Units.json`      | Measurement units                  | 33    |
| `Categories.json` | Recipe categories                  | 22    |
| `Tags.json`       | Recipe tags                        | 48    |
| `Tools.json`      | Kitchen equipment                  | 121   |
| `Foods/`          | Ingredients by label               | 1000+ |

## Import Order

To sync this data to your local Mealie instance, execute the following commands from the MealieSync root folder:

```powershell
# 1. Labels first
.\Invoke-MealieSync.ps1 -Action Import -Type Labels -JsonPath .\Data\en\Labels.json

# 2. Units
.\Invoke-MealieSync.ps1 -Action Import -Type Units -JsonPath .\Data\en\Units.json

# 3. Foods (references labels)
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\en\Foods

# 4. Recipe organizers
.\Invoke-MealieSync.ps1 -Action Import -Type Categories -JsonPath .\Data\en\Categories.json
.\Invoke-MealieSync.ps1 -Action Import -Type Tools -JsonPath .\Data\en\Tools.json