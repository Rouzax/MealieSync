# Changelog

All notable changes to MealieSync will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-01-08

### Added

- **Tag Merge Feature**: New `mergeTags` field in Tags JSON to consolidate multiple tags into one
  - Automatically transfers recipes from source tags to target tag
  - Source tags are deleted after merge
  - Supports both Import and Mirror operations
  - Full `-WhatIf` support for previewing merge operations
  
  ```json
  {
    "name": "aziatisch",
    "mergeTags": ["oosters", "sri-lankaans"]
  }
  ```

- **New private API functions**:
  - `Get-MealieTagBySlug` - Fetch tag with recipe list by slug
  - `Add-TagsToRecipes` - Bulk-add tags to multiple recipes
  - `Get-EmptyTags` - List tags with no recipe associations

- **New validation function**: `Confirm-TagMergeData` prevents circular/chained merges
  - Detects when a tag is both source and target (not allowed)
  - Warns about missing source tags (continues processing)
  - Detects duplicate sources (same tag merged to multiple targets)

- **New stats fields**: Import/Sync statistics now include:
  - `TagsMerged` - Number of source tags merged and deleted
  - `RecipesMoved` - Number of recipes that received new tags

### Changed

- `Import-MealieOrganizers` and `Sync-MealieOrganizers` now process `mergeTags` before standard operations
- `Write-ImportSummary` displays merge statistics when present

### Technical Details

| Component              | Count |
| ---------------------- | ----- |
| New private functions  | 6     |
| Test scenarios         | 7     |
| Total functions        | 105   |

---

## [2.0.0] - 2026-01-06

### ⚠️ Breaking Changes

- **JSON format changed**: All JSON files now require a wrapper with `$schema`, `$type`, and `$version` metadata. Legacy raw array format is no longer supported.
- **Module restructured**: Functions moved to `Public/` and `Private/` folders. Import using `MealieApi.psd1` instead of `MealieApi.psm1`.
- **Data folder restructured**: Language-specific data now in `Data/{language-code}/` subfolders (e.g., `Data/nl/`).

### Added

- **Mirror action**: New `Sync-Mealie*` functions and `-Action Mirror` CLI option for full bidirectional sync that adds, updates, AND deletes items to match JSON exactly
- **Mirror confirmation flow**: Mirror now shows a preview summary and prompts for confirmation before executing changes. Use `-WhatIf` for preview only, or `-Force` to skip confirmation.
- **Recipe usage protection**: Before deleting foods during Mirror operations, checks if each food is used in recipes. Foods linked to recipes are automatically blocked from deletion to prevent broken ingredient references.
- **Quiet mode for imports**: `-Quiet` parameter on `Import-MealieFoods` suppresses console output while still returning stats (used internally for preview)
- **Type validation**: Import operations validate that JSON `$type` matches expected data type, preventing accidental imports of wrong data
- **ReplaceAliases option**: `-ReplaceAliases` parameter to replace aliases instead of merging on import/sync
- **SkipBackup option**: `-SkipBackup` parameter to skip automatic backup before import/mirror operations
- **Force option**: `-Force` parameter for Mirror action to skip preview and confirmation prompt
- **Automatic backups**: Import and Mirror operations create automatic backup before making changes
- **Redundant alias filtering**: Aliases matching `name` or `pluralName` are automatically removed on import/export
- **Module manifest**: Proper `MealieApi.psd1` for better module management
- **Standalone tools**:
  - `Test-MealieConnection.ps1` - Verify API connectivity and authentication
  - `Show-MealieStats.ps1` - Dashboard with item counts and statistics
  - `Backup-MealieData.ps1` - Create timestamped full backups
  - `Convert-MealieSyncJson.ps1` - Migrate legacy JSON to new wrapper format
- **Household validation**: Validates household names in Foods and Tools against Mealie API
- **Enhanced change detection**: More accurate detection of actual changes before making API calls
- **Multi-language data support**: Data organized by language code with contribution guidelines

### Changed

- **Project structure**: Reorganized into `Public/`, `Private/`, and `Tools/` folders
- **Function organization**: 47 public functions across 18 files, 52 private helper functions across 9 files
- **Error messages**: Improved error messages with clear guidance
- **Progress output**: Enhanced progress bars and result summaries
- **JSON export format**: Now includes wrapper metadata for type safety

### Improved

- **Code quality**: Consistent `[CmdletBinding()]` on all functions
- **ShouldProcess support**: All modifying operations support `-WhatIf` preview
- **Documentation**: Comment-based help on all public functions
- **UTF-8 handling**: Consistent UTF-8 encoding throughout

### Technical Details

| Component         | Count |
| ----------------- | ----- |
| Public functions  | 47    |
| Private functions | 52    |
| Standalone tools  | 4     |
| Total functions   | 103   |

### Migration Guide

1. **Update JSON files**: Add wrapper format to existing JSON files:
   ```json
   {
     "$schema": "mealie-sync",
     "$type": "Foods",
     "$version": "1.0",
     "items": [ ... your existing array ... ]
   }
   ```
   
   Or use the migration tool:
   ```powershell
   .\Tools\Convert-MealieSyncJson.ps1 -Path .\Foods.json -Type Foods
   ```

2. **Update import statements**: Change from `Import-Module .\MealieApi.psm1` to `Import-Module .\MealieApi.psd1`

3. **Test connection**: Run `.\Tools\Test-MealieConnection.ps1` to verify setup

---

## [1.0.0] - Initial Release

- Basic import/export functionality
- Foods, Units, Labels, Categories, Tags, Tools support
- Smart duplicate matching
- Change detection
- WhatIf preview mode