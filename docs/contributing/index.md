# Contributing

Thank you for your interest in contributing to MealieSync!

## Ways to Contribute

### Data Contributions (Easiest)

Translate ingredient data to your language or expand existing databases. See the [data contribution guide](data-guide.md) for detailed guidelines.

### Bug Reports

Found a bug? [Open an issue](https://github.com/Rouzax/MealieSync/issues) with:

- PowerShell version (`$PSVersionTable.PSVersion`)
- Mealie version
- Steps to reproduce
- Expected vs actual behavior
- Relevant error messages

### Feature Requests

Have an idea? [Open an issue](https://github.com/Rouzax/MealieSync/issues) describing:

- The problem you are trying to solve
- Your proposed solution
- Alternative approaches you considered

### Code Contributions

Pull requests are welcome! Please follow the guidelines below.

## Development Setup

### Prerequisites

- PowerShell 7.0+
- A Mealie v2.x instance for testing
- Git

### Getting Started

```powershell
git clone https://github.com/Rouzax/MealieSync.git
cd MealieSync

Copy-Item mealie-config-sample.json mealie-config.json
# Edit mealie-config.json with your Mealie URL and token

.\Tools\Test-MealieConnection.ps1 -Detailed
Import-Module .\MealieApi.psd1
```

## Code Guidelines

### Project Structure

```
MealieSync/
├── Public/         # Exported functions (user-facing)
├── Private/        # Internal helper functions
├── Tools/          # Standalone utility scripts
└── Data/           # Language-specific ingredient data
```

### PowerShell Style

- Use `[CmdletBinding()]` on all functions
- Support `-WhatIf` for modifying operations
- Include comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`)
- Use approved verbs (`Get-`, `New-`, `Update-`, `Remove-`, `Import-`, `Export-`, `Sync-`)
- Handle errors gracefully with try/catch

### Naming Conventions

| Type              | Convention                     | Example            |
| ----------------- | ------------------------------ | ------------------ |
| Public functions  | `Verb-MealieNoun`              | `Get-MealieFoods`  |
| Private functions | `Verb-Noun` (no Mealie prefix) | `Build-FoodLookup` |
| Variables         | camelCase                      | `$existingItems`   |
| Parameters        | PascalCase                     | `-UpdateExisting`  |

### Console Output

MealieSync uses consistent colors for user feedback. See the [color system](color-system.md) for the full guide.

### Testing

Before submitting:

1. Test with `-WhatIf` to verify preview output
2. Test against a real Mealie instance
3. Verify UTF-8 encoding works (test with special characters like `jalapeño`, `maïs`)
4. Check that existing functionality still works

## Pull Request Process

1. Fork the repository
2. Create a branch for your changes (`feature/my-feature` or `fix/bug-description`)
3. Make your changes following the guidelines above
4. Test thoroughly with your Mealie instance
5. Update documentation if needed
6. Submit a pull request with a clear description

### PR Checklist

- [ ] Code follows the project style
- [ ] Functions include comment-based help
- [ ] Tested with PowerShell 7.x
- [ ] No breaking changes (or clearly documented)
- [ ] Documentation updated if needed

## Questions?

Feel free to [open an issue](https://github.com/Rouzax/MealieSync/issues) or start a discussion.
