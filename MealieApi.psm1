#Requires -Version 7.0
<#
.SYNOPSIS
    MealieSync - PowerShell module for Mealie API management
.DESCRIPTION
    Provides functions to interact with the Mealie REST API for managing:
    - Foods (ingredients) with labels and aliases
    - Units with abbreviations and aliases  
    - Labels for food categorization
    - Organizers (Categories, Tags, Tools) for recipes
    
    Supports import/export functionality with JSON data files.
.NOTES
    Module: MealieApi
    Version: 2.0.0
    Author: Rouzax
    
    This module uses a Public/Private folder structure:
    - Public/  : Exported functions (API surface)
    - Private/ : Internal helper functions
    - Tools/   : Standalone utility scripts
#>

#region Module-level Variables

# API configuration (populated by Initialize-MealieApi)
$script:MealieConfig = @{
    BaseUrl = $null
    Token   = $null
    Headers = $null
}

# Household cache (populated on first use, for validation)
$script:HouseholdCache = $null

#endregion Module-level Variables

#region Dot-source Loader

# Load private functions first (internal helpers)
$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
if (Test-Path -Path $privatePath) {
    $privateFiles = Get-ChildItem -Path $privatePath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $privateFiles) {
        try {
            Write-Verbose "Loading private function: $($file.Name)"
            . $file.FullName
        }
        catch {
            Write-Error "Failed to load private function $($file.Name): $_"
        }
    }
}

# Load public functions (exported API)
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
if (Test-Path -Path $publicPath) {
    $publicFiles = Get-ChildItem -Path $publicPath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $publicFiles) {
        try {
            Write-Verbose "Loading public function: $($file.Name)"
            . $file.FullName
        }
        catch {
            Write-Error "Failed to load public function $($file.Name): $_"
        }
    }
}

#endregion Dot-source Loader


# NOTE: All functions have been extracted to separate files.
#
# This module file now only contains:
#   - Module-level variables ($script:MealieConfig, $script:HouseholdCache)
#   - Dot-source loader for Public/ and Private/ folders
#
# EXTRACTED TO Private/:
#   - Invoke-MealieRequest       → Private/Invoke-MealieRequest.ps1
#   - Compare-StringValue        → Private/Compare-Helpers.ps1
#   - Compare-Aliases            → Private/Compare-Helpers.ps1
#   - Compare-HouseholdArray     → Private/Compare-Helpers.ps1
#   - Merge-Aliases              → Private/Compare-Helpers.ps1
#   - Test-FoodChanged           → Private/Test-ItemChanged.ps1
#   - Test-UnitChanged           → Private/Test-ItemChanged.ps1
#   - Test-LabelChanged          → Private/Test-ItemChanged.ps1
#   - Test-OrganizerChanged      → Private/Test-ItemChanged.ps1
#   - Test-ToolChanged           → Private/Test-ItemChanged.ps1
#   - Validation helpers         → Private/Validation-Helpers.ps1
#   - Build-*Lookups             → Private/Build-Lookups.ps1
#   - Write-* helpers            → Private/Write-Helpers.ps1
#   - Export helpers             → Private/Export-Helpers.ps1
#   - Import helpers             → Private/Import-Helpers.ps1
#
# EXTRACTED TO Public/:
#   - Initialize-MealieApi       → Public/Initialize-MealieApi.ps1
#   - Get/New/Update/Remove-MealieFood  → Public/Foods.ps1
#   - Get/New/Update/Remove-MealieUnit  → Public/Units.ps1
#   - Get/New/Update/Remove-MealieLabel → Public/Labels.ps1
#   - Get/New/Update/Remove-MealieCategory/Tag/Tool → Public/Organizers.ps1
#   - Get-MealieHouseholds       → Public/Households.ps1
#   - Export-MealieFoods         → Public/Export-MealieFoods.ps1
#   - Export-MealieUnits         → Public/Export-MealieUnits.ps1
#   - Export-MealieLabels        → Public/Export-MealieLabels.ps1
#   - Export-MealieOrganizers    → Public/Export-MealieOrganizers.ps1
#   - Import-MealieFoods         → Public/Import-MealieFoods.ps1
#   - Import-MealieUnits         → Public/Import-MealieUnits.ps1
#   - Import-MealieLabels        → Public/Import-MealieLabels.ps1
#   - Import-MealieOrganizers    → Public/Import-MealieOrganizers.ps1
#   - Import-MealieCategories    → Public/Import-MealieOrganizers.ps1
#   - Import-MealieTags          → Public/Import-MealieOrganizers.ps1
#   - Import-MealieTools         → Public/Import-MealieOrganizers.ps1

# Note: Export-ModuleMember is handled by the module manifest (MealieApi.psd1)
# The manifest's FunctionsToExport list is authoritative for what gets exported.
