#Requires -Version 7.0
<#
.SYNOPSIS
    Comparison helper functions for MealieSync
.DESCRIPTION
    Internal helper functions for comparing values in change detection.
    Handles null values, case-insensitivity, and array comparisons.
.NOTES
    This is a private function file - not exported by the module.
#>

function Compare-StringValue {
    <#
    .SYNOPSIS
        Compare two string values with null-safety
    .DESCRIPTION
        Compares two strings treating null and empty string as equal.
        Trims whitespace before comparison. Uses ordinal comparison
        to correctly handle diacritics (ç ≠ c, ï ≠ i, etc.).
    .PARAMETER Existing
        The existing value from the API
    .PARAMETER New
        The new value from import data
    .OUTPUTS
        [bool] True if values are equal, False if different
    .EXAMPLE
        Compare-StringValue -Existing "test" -New "test"  # Returns $true
        Compare-StringValue -Existing $null -New ""       # Returns $true
        Compare-StringValue -Existing "a" -New "b"        # Returns $false
        Compare-StringValue -Existing "maïs" -New "mais"  # Returns $false (diacritics matter)
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Existing,
        
        [AllowNull()]
        [AllowEmptyString()]
        [string]$New
    )
    
    # Normalize null/empty to empty string, trim whitespace
    $existingNorm = if ([string]::IsNullOrEmpty($Existing)) { "" } else { $Existing.Trim() }
    $newNorm = if ([string]::IsNullOrEmpty($New)) { "" } else { $New.Trim() }
    
    # Use ordinal comparison to preserve diacritic differences
    return [string]::Equals($existingNorm, $newNorm, [StringComparison]::Ordinal)
}

function Compare-Aliases {
    <#
    .SYNOPSIS
        Compare two alias arrays for equality
    .DESCRIPTION
        Compares alias arrays by extracting names, normalizing case,
        sorting, and comparing element-by-element. Uses ordinal comparison
        to correctly handle diacritics.
    .PARAMETER Existing
        Array of existing alias objects (with .name property)
    .PARAMETER New
        Array of new alias objects (with .name property)
    .OUTPUTS
        [bool] True if alias sets are equal, False if different
    .EXAMPLE
        Compare-Aliases -Existing @(@{name='a'}, @{name='b'}) -New @(@{name='B'}, @{name='A'})
        # Returns $true (case-insensitive, order doesn't matter)
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [array]$Existing,
        
        [AllowNull()]
        [array]$New
    )
    
    # Extract and normalize alias names
    $existingNames = @()
    if ($Existing) {
        $existingNames = @($Existing | ForEach-Object { $_.name.ToLower().Trim() } | Sort-Object)
    }
    
    $newNames = @()
    if ($New) {
        $newNames = @($New | ForEach-Object { $_.name.ToLower().Trim() } | Sort-Object)
    }
    
    # Compare counts first (fast path)
    if ($existingNames.Count -ne $newNames.Count) {
        return $false
    }
    
    # Compare each element using ordinal comparison (preserves diacritics)
    for ($i = 0; $i -lt $existingNames.Count; $i++) {
        if (-not [string]::Equals($existingNames[$i], $newNames[$i], [StringComparison]::Ordinal)) {
            return $false
        }
    }
    
    return $true
}

function Compare-HouseholdArray {
    <#
    .SYNOPSIS
        Compare two household arrays for equality
    .DESCRIPTION
        Compares arrays of household names (strings) with case-insensitive matching.
        Used for householdsWithIngredientFood and householdsWithTool comparisons.
        Uses ordinal comparison to correctly handle any special characters.
    .PARAMETER Existing
        Array of existing household names
    .PARAMETER New
        Array of new household names
    .OUTPUTS
        [bool] True if arrays contain the same households, False if different
    .EXAMPLE
        Compare-HouseholdArray -Existing @('Home', 'Work') -New @('work', 'home')
        # Returns $true (case-insensitive, order doesn't matter)
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [array]$Existing,
        
        [AllowNull()]
        [array]$New
    )
    
    # Normalize to lowercase, sorted arrays
    $existingNorm = @()
    if ($Existing) {
        $existingNorm = @($Existing | ForEach-Object { $_.ToLower().Trim() } | Sort-Object)
    }
    
    $newNorm = @()
    if ($New) {
        $newNorm = @($New | ForEach-Object { $_.ToLower().Trim() } | Sort-Object)
    }
    
    # Compare counts first (fast path)
    if ($existingNorm.Count -ne $newNorm.Count) {
        return $false
    }
    
    # Compare each element using ordinal comparison
    for ($i = 0; $i -lt $existingNorm.Count; $i++) {
        if (-not [string]::Equals($existingNorm[$i], $newNorm[$i], [StringComparison]::Ordinal)) {
            return $false
        }
    }
    
    return $true
}

# Note: Merge-Aliases has been moved to Import-Helpers.ps1 with ReplaceMode parameter
