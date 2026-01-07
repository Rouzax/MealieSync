#Requires -Version 7.0
<#
.SYNOPSIS
    Validation helper functions for MealieSync
.DESCRIPTION
    Internal helper functions for validating JSON format, extracting items,
    and validating household names against the Mealie API.
.NOTES
    This is a private function file - not exported by the module.
#>

function Test-JsonWrapper {
    <#
    .SYNOPSIS
        Check if JSON data has the new wrapper format
    .DESCRIPTION
        Tests whether the imported JSON data contains the $schema, $type, 
        and $version properties indicating the new MealieSync format.
    .PARAMETER Data
        The parsed JSON data object
    .OUTPUTS
        [bool] True if data has wrapper format, False if raw array
    .EXAMPLE
        $json = Get-Content 'Foods.json' | ConvertFrom-Json
        if (Test-JsonWrapper -Data $json) {
            # New format with metadata
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Data
    )
    
    # Check for wrapper properties
    return (
        $Data.PSObject.Properties.Name -contains '$schema' -and
        $Data.PSObject.Properties.Name -contains '$type' -and
        $Data.PSObject.Properties.Name -contains '$version'
    )
}

function Get-JsonItems {
    <#
    .SYNOPSIS
        Extract items array from JSON data
    .DESCRIPTION
        Returns the items array from the new wrapper format.
        Legacy raw array format is NOT supported - use Convert-MealieSyncJson.ps1 to migrate.
    .PARAMETER Data
        The parsed JSON data object
    .OUTPUTS
        [array] The items array from the JSON data
    .EXAMPLE
        $json = Get-Content 'Foods.json' | ConvertFrom-Json
        $items = Get-JsonItems -Data $json
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [object]$Data
    )
    
    if (Test-JsonWrapper -Data $Data) {
        # New format: extract items array
        return @($Data.items)
    }
    else {
        # Legacy format not supported
        Write-Warning "Legacy JSON format detected. Use Convert-MealieSyncJson.ps1 to migrate."
        return @()
    }
}

function Get-JsonType {
    <#
    .SYNOPSIS
        Get the type from JSON wrapper
    .DESCRIPTION
        Returns the $type value from a wrapped JSON file.
        Returns $null if not in wrapper format.
    .PARAMETER Data
        The parsed JSON data object
    .OUTPUTS
        [string] The type value (Foods, Units, Labels, etc.) or $null
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Data
    )
    
    if (Test-JsonWrapper -Data $Data) {
        return $Data.'$type'
    }
    return $null
}

function Test-JsonType {
    <#
    .SYNOPSIS
        Validate that JSON data matches expected type
    .DESCRIPTION
        Checks if the $type in the JSON wrapper matches the expected type.
        Legacy format (no wrapper) is NOT accepted - type validation is mandatory
        to prevent accidental imports of wrong data types.
    .PARAMETER Data
        The parsed JSON data object
    .PARAMETER ExpectedType
        The expected type (Foods, Units, Labels, Categories, Tags, Tools)
    .OUTPUTS
        [bool] True if type matches, False if mismatch or missing wrapper
    .EXAMPLE
        if (-not (Test-JsonType -Data $json -ExpectedType 'Foods')) {
            throw "Invalid file type - use Convert-MealieSyncJson.ps1 to migrate"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Data,
        
        [Parameter(Mandatory)]
        [ValidateSet('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools')]
        [string]$ExpectedType
    )
    
    $actualType = Get-JsonType -Data $Data
    
    # If no wrapper (legacy format), reject - type validation is mandatory
    if ($null -eq $actualType) {
        return $false
    }
    
    # Compare case-insensitively
    return $actualType -eq $ExpectedType
}

function Get-ValidHouseholds {
    <#
    .SYNOPSIS
        Get list of valid household names from Mealie
    .DESCRIPTION
        Fetches the list of households from the API and caches the result
        in the module-scoped $HouseholdCache variable for reuse.
    .PARAMETER Force
        Force refresh of the cache
    .OUTPUTS
        [array] Array of household objects with id, name, slug properties
    .EXAMPLE
        $households = Get-ValidHouseholds
        $validNames = $households.name
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [switch]$Force
    )
    
    # Return cached value if available and not forcing refresh
    if ($script:HouseholdCache -and -not $Force) {
        return $script:HouseholdCache
    }
    
    try {
        # Fetch households from API
        $response = Invoke-MealieRequest -Endpoint '/api/groups/households' -Method 'GET'
        
        # Handle both array and paginated response formats
        if ($response.items) {
            $script:HouseholdCache = @($response.items)
        }
        else {
            $script:HouseholdCache = @($response)
        }
        
        return $script:HouseholdCache
    }
    catch {
        Write-Warning "Failed to fetch households: $_"
        return @()
    }
}

function Test-HouseholdExists {
    <#
    .SYNOPSIS
        Validate that a household name exists
    .DESCRIPTION
        Checks if the given household name exists in the Mealie instance.
        Uses case-insensitive matching.
    .PARAMETER Name
        The household name to validate
    .OUTPUTS
        [bool] True if household exists, False otherwise
    .EXAMPLE
        if (-not (Test-HouseholdExists -Name 'groothuis')) {
            Write-Warning "Invalid household: groothuis"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    $households = Get-ValidHouseholds
    $normalized = $Name.ToLower().Trim()
    
    foreach ($household in $households) {
        if ($household.name.ToLower().Trim() -eq $normalized) {
            return $true
        }
    }
    
    return $false
}

function Test-AllHouseholdsExist {
    <#
    .SYNOPSIS
        Validate that all household names in a list exist
    .DESCRIPTION
        Checks each household name in the array against valid households.
        Returns a result object with validation status and invalid names.
    .PARAMETER Names
        Array of household names to validate
    .OUTPUTS
        [hashtable] @{ Valid = [bool]; InvalidNames = [array] }
    .EXAMPLE
        $result = Test-AllHouseholdsExist -Names @('groothuis', 'invalid')
        if (-not $result.Valid) {
            Write-Warning "Invalid households: $($result.InvalidNames -join ', ')"
        }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [AllowNull()]
        [array]$Names
    )
    
    $result = @{
        Valid        = $true
        InvalidNames = @()
    }
    
    if (-not $Names -or $Names.Count -eq 0) {
        return $result
    }
    
    foreach ($name in $Names) {
        if (-not (Test-HouseholdExists -Name $name)) {
            $result.Valid = $false
            $result.InvalidNames += $name
        }
    }
    
    return $result
}

function Confirm-ImportData {
    <#
    .SYNOPSIS
        Validate import data before processing
    .DESCRIPTION
        Performs upfront validation of import data including:
        - JSON type validation (if wrapped format)
        - Household name validation
        Returns detailed validation results.
    .PARAMETER Data
        The parsed JSON data object
    .PARAMETER ExpectedType
        The expected data type
    .PARAMETER ValidateHouseholds
        Whether to validate household names
    .OUTPUTS
        [hashtable] Validation result with Valid, Errors, Warnings properties
    .EXAMPLE
        $result = Confirm-ImportData -Data $json -ExpectedType 'Foods' -ValidateHouseholds
        if (-not $result.Valid) {
            $result.Errors | ForEach-Object { Write-Error $_ }
            return
        }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object]$Data,
        
        [Parameter(Mandatory)]
        [ValidateSet('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools')]
        [string]$ExpectedType,
        
        [switch]$ValidateHouseholds
    )
    
    $result = @{
        Valid    = $true
        Errors   = @()
        Warnings = @()
    }
    
    # Validate JSON type - wrapper format is required
    if (-not (Test-JsonType -Data $Data -ExpectedType $ExpectedType)) {
        $actualType = Get-JsonType -Data $Data
        $result.Valid = $false
        if ($null -eq $actualType) {
            $result.Errors += "Missing type wrapper. Legacy format not supported. Use Convert-MealieSyncJson.ps1 to migrate."
        }
        else {
            $result.Errors += "Type mismatch: File contains '$actualType' but you specified -Type $ExpectedType"
            $result.Errors += "  Hint: Use -Type $actualType instead, or check you selected the correct file"
        }
    }
    
    # Get items for further validation
    $items = Get-JsonItems -Data $Data
    
    if ($items.Count -eq 0) {
        $result.Warnings += "No items found in import data"
    }
    
    # Validate households if requested
    if ($ValidateHouseholds) {
        $allHouseholds = @()
        
        foreach ($item in $items) {
            # Check householdsWithIngredientFood (Foods)
            if ($item.householdsWithIngredientFood) {
                $allHouseholds += $item.householdsWithIngredientFood
            }
            # Check householdsWithTool (Tools)
            if ($item.householdsWithTool) {
                $allHouseholds += $item.householdsWithTool
            }
        }
        
        if ($allHouseholds.Count -gt 0) {
            $uniqueHouseholds = $allHouseholds | Select-Object -Unique
            $householdResult = Test-AllHouseholdsExist -Names $uniqueHouseholds
            
            if (-not $householdResult.Valid) {
                $result.Valid = $false
                $result.Errors += "Invalid household(s): $($householdResult.InvalidNames -join ', ')"
            }
        }
    }
    
    return $result
}
