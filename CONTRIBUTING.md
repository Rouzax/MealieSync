# Contributing to MealieSync

Thank you for your interest in contributing! Full guidelines are on the **[documentation site](https://rouzax.github.io/MealieSync/contributing/)**.

## Quick Links

- **[Data contributions](https://rouzax.github.io/MealieSync/contributing/data-guide/)** (translations, new ingredients)
- **[Code guidelines](https://rouzax.github.io/MealieSync/contributing/)** (style, naming, testing)
- **[Bug reports](https://github.com/Rouzax/MealieSync/issues)** (include PowerShell version, Mealie version, steps to reproduce)
- **[Feature requests](https://github.com/Rouzax/MealieSync/issues)** (describe the problem you are trying to solve)

## Getting Started

```powershell
git clone https://github.com/Rouzax/MealieSync.git
cd MealieSync

Copy-Item mealie-config-sample.json mealie-config.json
# Edit mealie-config.json with your Mealie URL and token

.\Tools\Test-MealieConnection.ps1 -Detailed
```
