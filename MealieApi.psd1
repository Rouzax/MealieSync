@{
    # Module manifest for MealieApi
    # Generated for MealieSync v2.2.1

    # Script module or binary module file associated with this manifest
    RootModule = 'MealieApi.psm1'

    # Version number of this module
    ModuleVersion = '2.2.1'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'Rouzax'

    # Company or vendor of this module
    CompanyName = 'N/A'

    # Copyright statement for this module
    Copyright = '(c) 2025 Rouzax. MIT License.'

    # Description of the functionality provided by this module
    Description = 'PowerShell module for managing Mealie data via REST API. Supports Foods, Units, Labels, Categories, Tags, and Tools with import/export functionality.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Functions to export from this module
    # Note: Will be populated as functions are moved to Public/ folder
    # For now, export all functions via wildcard (will be refined in later phases)
    FunctionsToExport = @(
        # API Initialization
        'Initialize-MealieApi'
        
        # Foods
        'Get-MealieFoods'
        'New-MealieFood'
        'Update-MealieFood'
        'Remove-MealieFood'
        'Import-MealieFoods'
        'Export-MealieFoods'
        
        # Units
        'Get-MealieUnits'
        'New-MealieUnit'
        'Update-MealieUnit'
        'Remove-MealieUnit'
        'Import-MealieUnits'
        'Export-MealieUnits'
        
        # Labels
        'Get-MealieLabels'
        'New-MealieLabel'
        'Update-MealieLabel'
        'Remove-MealieLabel'
        'Import-MealieLabels'
        'Export-MealieLabels'
        
        # Categories
        'Get-MealieCategories'
        'New-MealieCategory'
        'Update-MealieCategory'
        'Remove-MealieCategory'
        'Import-MealieCategories'
        'Export-MealieCategories'
        
        # Tags
        'Get-MealieTags'
        'New-MealieTag'
        'Update-MealieTag'
        'Remove-MealieTag'
        'Import-MealieTags'
        'Export-MealieTags'
        
        # Tools
        'Get-MealieTools'
        'New-MealieTool'
        'Update-MealieTool'
        'Remove-MealieTool'
        'Import-MealieTools'
        'Export-MealieTools'
        
        # Generic Import
        'Import-MealieOrganizers'
        
        # Generic Export
        'Export-MealieOrganizers'
        
        # Sync (Mirror) Functions
        'Sync-MealieFoods'
        'Sync-MealieUnits'
        'Sync-MealieLabels'
        'Sync-MealieOrganizers'
        'Sync-MealieCategories'
        'Sync-MealieTags'
        'Sync-MealieTools'
        
        # Households
        'Get-MealieHouseholds'
        
        # Conflict Detection
        'Test-MealieFoodConflicts'
        'Test-MealieUnitConflicts'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for online discovery
            Tags = @('Mealie', 'API', 'Food', 'Recipe', 'Ingredients')

            # License URI for this module
            LicenseUri = 'https://github.com/Rouzax/MealieSync/blob/main/LICENSE'

            # Project URI for this module
            ProjectUri = 'https://github.com/Rouzax/MealieSync'

            # Release notes for this module
            ReleaseNotes = @'
Version 2.2.1 - Mirror Bug Fixes
- Fixed critical bug where items matched via alias were incorrectly deleted
- Mirror operations now check for conflicts once instead of three times
- Replaced box-style headers with simple double-line headers for consistent rendering

Version 2.2.0 - Conflict Detection
- New Test-MealieFoodConflicts and Test-MealieUnitConflicts functions
- Detects within-file AND cross-file duplicates
- Single-file imports/syncs now check for internal conflicts
- New -Folder and -Recurse parameters for bulk operations
- Clear visual report grouped by scope (within-file vs cross-file)
- Conflicts block operation with actionable report

Version 2.1.1 - Bug Fix
- Fixed redundant alias detection in replace mode

Version 2.1.0 - Tag Merge Feature
- New mergeTags field for consolidating tags
- Automatically transfers recipes from source to target tags
- Source tags deleted after merge
- Full -WhatIf preview support
- New stats: TagsMerged, RecipesMoved

Version 2.0.0 - Major Refactoring
- Restructured to Public/Private folder pattern
- Added module manifest
- Improved error handling and validation
- New JSON format with schema validation
- New features: Mirror action, ReplaceAliases, SkipBackup
'@
        }
    }
}
