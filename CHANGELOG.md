# Changelog

All notable changes to MealieSync will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Dutch food data files renamed to match their label names exactly (e.g., `groente.json` is now `Groente.json`). Consistent with the French dataset.
- Fixed extra leading whitespace in `mealie-config-sample.json`.

### Fixed

- Folder mirror no longer tries to delete items that belong to other files. Previously, each file in a folder mirror ran its own independent delete phase, causing massively inflated delete counts and potential data loss. Now all files are treated as one combined dataset for deletion.
- Same fix applied to unit folder mirror (`Sync-MealieUnits -Folder`).
- Export with `-SplitByLabel` showed wrong file count when all foods shared one label (e.g., "101 foods in 101 files" instead of "101 foods in 1 files").
- `-SplitByLabel` was silently accepted for non-Food types. Now shows a warning and ignores the flag.
- `Get-Help .\Invoke-MealieSync.ps1` now shows full help (synopsis, description, examples). Previously showed only the syntax line.
- File paths in console output no longer contain `./` artifacts (e.g., `/path/MealieSync/./Data/...`).
- Import mode display no longer shows the "Replace aliases" hint for types that don't have aliases (Categories, Tags, Tools).
- Backup tool output no longer interleaves export function messages with its own status lines.
- Input file/folder existence is now validated before connecting to the Mealie API.
- `-Force`, `-Label`, and other parameters now warn when used with actions or types where they have no effect, instead of being silently ignored.

### Added

- Pester test suite with 12 tests covering folder mirror deletion logic and item matching.

## [2.4.0] - 2026-05-15

### Added

- Update check: MealieSync now checks GitHub for newer releases (cached for 24 hours) and shows a one-line notice with instructions to update.
- Version display in `Test-MealieConnection.ps1` output.
- Automated GitHub Releases: pushing a version tag creates a release with a downloadable ZIP and changelog notes.
- Rewritten CHANGELOG in user-focused style.

## [2.3.1] - 2026-05-15

### Fixed

- Food import now works when importing to a second household on the same Mealie server. UUID collisions are detected automatically and the import continues without UUIDs.

### Added

- MkDocs documentation site with Material theme, auto-deployed to GitHub Pages.
- LLM ingredient curator prompt kit for generating and improving Dutch food data (`Data/nl/llm-prompt/`).

### Changed

- README trimmed from ~1000 lines to ~140 lines. All detailed content moved to the documentation site.
- Food rules files cleaned up: fixed em-dashes, aligned description limit to 100 characters.

## [2.3.0] - 2026-05-14

### Added

- French ingredient dataset: 1,311 foods with full translations, aliases, labels, and descriptions.
- Stable UUIDs across languages: Dutch and French datasets share food identifiers, so "aardappel" and "pomme de terre" are linked by the same UUID.
- Food creation now preserves UUIDs from JSON data files. Previously Mealie assigned new UUIDs on every import.

## [2.2.2] - 2026-05-14

### Fixed

- Import no longer fails on an empty Mealie instance. The lookup builder now handles the case where no items exist yet.

## [2.2.1] - 2026-01-09

### Fixed

- Mirror no longer marks items for deletion when they were matched via alias. The delete phase now uses the same comprehensive matching logic as import (name, pluralName, and aliases).
- Mirror operations now check for conflicts once instead of three times.

### Changed

- Replaced box-style headers with simple double-line headers for consistent terminal rendering.

## [2.2.0] - 2026-01-09

### Added

- Conflict detection: catch duplicate items within and across JSON files before import. Blocks the operation if conflicts are found.
- Folder import: import all JSON files from a folder at once with `-Folder` parameter.
- Manual conflict checking with `Test-MealieFoodConflicts` and `Test-MealieUnitConflicts`.

## [2.1.1] - 2026-01-09

### Fixed

- Foods and Units with aliases matching their plural name no longer trigger unnecessary updates on every import.

## [2.1.0] - 2026-01-08

### Added

- Tag merging: consolidate multiple tags into one with `mergeTags` in your Tags JSON. Recipes are automatically transferred before source tags are deleted.
- Full `-WhatIf` support for previewing tag merge operations.
- Validation prevents circular or chained merges.

## [2.0.0] - 2026-01-06

### Breaking Changes

- JSON files now require a wrapper format with `$schema`, `$type`, and `$version` metadata. Use `Tools/Convert-MealieSyncJson.ps1` to migrate existing files.
- Import the module using `MealieApi.psd1` instead of `MealieApi.psm1`.
- Language-specific data moved to `Data/{language-code}/` subfolders.

### Added

- Mirror action: full bidirectional sync that adds, updates, and deletes items to match your JSON exactly.
- Recipe usage protection: foods used in recipes are blocked from deletion during Mirror.
- Automatic backups before import and mirror operations.
- `-WhatIf` preview on all modifying operations.
- `-ReplaceAliases` to replace aliases instead of merging.
- Standalone tools: `Test-MealieConnection.ps1`, `Show-MealieStats.ps1`, `Backup-MealieData.ps1`, `Convert-MealieSyncJson.ps1`.
- Household validation for Foods and Tools.

## [1.0.0] - Initial Release

- Import and export for Foods, Units, Labels, Categories, Tags, and Tools.
- Smart duplicate matching across names, plurals, and aliases.
- Change detection to avoid unnecessary API calls.
- `-WhatIf` preview mode.
