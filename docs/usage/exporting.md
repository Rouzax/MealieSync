# Exporting

Export saves items from your Mealie instance to JSON files. This is useful for creating backups, editing data offline, or bootstrapping a new language dataset.

## Basic Export

```powershell
# Export all foods to a single file
.\Invoke-MealieSync.ps1 -Action Export -Type Foods -JsonPath .\Exports\Foods.json

# Export only foods with a specific label
.\Invoke-MealieSync.ps1 -Action Export -Type Foods -JsonPath .\Exports\Vegetables.json -Label "Groente"
```

## Split by Label

For Foods, you can split the export into one file per label. This creates an organized folder structure that matches how the included datasets are organized:

```powershell
.\Invoke-MealieSync.ps1 -Action Export -Type Foods -Folder .\Exports\ByLabel -SplitByLabel
```

```
Exporting Foods to folder: .\Exports\ByLabel (split by label)
  Would export 31 foods to: Aardappelen & Knollen.json
  Would export 68 foods to: Bakproducten.json
  Would export 17 foods to: Bier.json
  Would export 96 foods to: Fruit.json
  Would export 101 foods to: Groente.json
  Would export 105 foods to: Kruiden & Specerijen.json
  Would export 84 foods to: Vlees.json
  ...

Total: 1312 foods in 28 files
```

Foods without a label are exported to `_No_Label.json`.

## Other Types

All data types support export:

```powershell
.\Invoke-MealieSync.ps1 -Action Export -Type Units -JsonPath .\Exports\Units.json
.\Invoke-MealieSync.ps1 -Action Export -Type Labels -JsonPath .\Exports\Labels.json
.\Invoke-MealieSync.ps1 -Action Export -Type Categories -JsonPath .\Exports\Categories.json
.\Invoke-MealieSync.ps1 -Action Export -Type Tags -JsonPath .\Exports\Tags.json
.\Invoke-MealieSync.ps1 -Action Export -Type Tools -JsonPath .\Exports\Tools.json
```

## Preview

Add `-WhatIf` to see what would be exported without writing any files:

```powershell
.\Invoke-MealieSync.ps1 -Action Export -Type Foods -JsonPath .\Foods.json -Label "Groente" -WhatIf
```

```
Exporting Foods with label 'Groente' to: .\Foods.json
Would export 101 foods with label 'Groente' to: .\Foods.json
```
