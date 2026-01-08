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

function Confirm-TagMergeData {
    <#
    .SYNOPSIS
        Validate mergeTags entries before processing
    .DESCRIPTION
        Validates the mergeTags field in tag import data to ensure:
        - No tag appears as both source and target (no chaining allowed)
        - Source tags that don't exist generate warnings (not errors)
        - Collects all valid merge operations for processing
        
        This validation runs BEFORE normal import validation to catch merge
        configuration errors early.
    .PARAMETER Items
        Array of tag items from the import data (may include mergeTags field)
    .PARAMETER ExistingTags
        Array of existing tag objects from the API (from Get-MealieTags -All)
    .OUTPUTS
        [hashtable] @{
            Valid = [bool]              # True if no blocking errors
            Errors = [array]            # Fatal errors that block processing
            Warnings = [array]          # Non-fatal warnings (e.g., missing source tags)
            MergeOperations = [array]   # Array of @{ TargetName; TargetSlug; SourceTags; ExistingSourceTags }
        }
    .EXAMPLE
        $tags = Get-MealieTags -All
        $result = Confirm-TagMergeData -Items $importData -ExistingTags $tags
        if (-not $result.Valid) {
            $result.Errors | ForEach-Object { Write-Error $_ }
            return
        }
        $result.Warnings | ForEach-Object { Write-Warning $_ }
    .EXAMPLE
        # Detect chained merge (should error)
        # Input: [{ name: "A", mergeTags: ["B"] }, { name: "B", mergeTags: ["C"] }]
        # Error: "B" appears as both target and source
    .NOTES
        Used by Import-MealieOrganizers and Sync-MealieOrganizers before
        processing tag imports. Merge operations are processed before normal
        import/delete operations.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Items,
        
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$ExistingTags
    )
    
    $result = @{
        Valid           = $true
        Errors          = @()
        Warnings        = @()
        MergeOperations = @()
    }
    
    # Build lookup for existing tags by name (case-insensitive)
    $existingByName = @{}
    $existingBySlug = @{}
    foreach ($tag in $ExistingTags) {
        if ($tag.name) {
            $existingByName[$tag.name.ToLower().Trim()] = $tag
        }
        if ($tag.slug) {
            $existingBySlug[$tag.slug.ToLower().Trim()] = $tag
        }
    }
    
    # Collect all targets and sources for chaining detection
    $allTargets = @{}    # name → item
    $allSources = @{}    # name → target name
    
    # First pass: collect all merge definitions
    foreach ($item in $Items) {
        if (-not $item.mergeTags -or $item.mergeTags.Count -eq 0) {
            continue
        }
        
        $targetName = $item.name.ToLower().Trim()
        $allTargets[$targetName] = $item
        
        foreach ($sourceTag in $item.mergeTags) {
            $sourceName = $sourceTag.ToLower().Trim()
            
            # Check if this source is already a target (chaining)
            if ($allTargets.ContainsKey($sourceName)) {
                $result.Valid = $false
                $result.Errors += "Chained merge detected: '$sourceTag' is both a merge target and a source for '$($item.name)'. Chained merges are not supported."
            }
            
            # Check if this source is already used by another target
            if ($allSources.ContainsKey($sourceName)) {
                $existingTarget = $allSources[$sourceName]
                if ($existingTarget -ne $targetName) {
                    $result.Valid = $false
                    $result.Errors += "Duplicate source: '$sourceTag' is listed as source for both '$($item.name)' and '$existingTarget'. A tag can only be merged into one target."
                }
            }
            else {
                $allSources[$sourceName] = $targetName
            }
        }
    }
    
    # Second pass: check if any target is also a source elsewhere
    foreach ($item in $Items) {
        if (-not $item.mergeTags -or $item.mergeTags.Count -eq 0) {
            continue
        }
        
        $targetName = $item.name.ToLower().Trim()
        
        if ($allSources.ContainsKey($targetName)) {
            $mergeIntoTarget = $allSources[$targetName]
            $result.Valid = $false
            $result.Errors += "Chained merge detected: '$($item.name)' is a merge target but is also listed as a source for '$mergeIntoTarget'. Chained merges are not supported."
        }
    }
    
    # If we have errors, don't continue building operations
    if (-not $result.Valid) {
        return $result
    }
    
    # Third pass: build merge operations and check source existence
    foreach ($item in $Items) {
        if (-not $item.mergeTags -or $item.mergeTags.Count -eq 0) {
            continue
        }
        
        $targetName = $item.name
        $targetSlug = if ($item.slug) { $item.slug } else { $targetName.ToLower() -replace '\s+', '-' }
        
        $existingSourceTags = @()
        $missingSourceTags = @()
        
        foreach ($sourceTagName in $item.mergeTags) {
            $sourceKey = $sourceTagName.ToLower().Trim()
            
            # Check if source exists (by name or slug)
            $existingSource = $null
            if ($existingByName.ContainsKey($sourceKey)) {
                $existingSource = $existingByName[$sourceKey]
            }
            elseif ($existingBySlug.ContainsKey($sourceKey)) {
                $existingSource = $existingBySlug[$sourceKey]
            }
            
            if ($existingSource) {
                $existingSourceTags += @{
                    Name = $existingSource.name
                    Slug = $existingSource.slug
                    Id   = $existingSource.id
                }
            }
            else {
                $missingSourceTags += $sourceTagName
            }
        }
        
        # Warn about missing source tags (non-fatal)
        if ($missingSourceTags.Count -gt 0) {
            $result.Warnings += "Merge target '$targetName': Source tag(s) not found and will be skipped: $($missingSourceTags -join ', ')"
        }
        
        # Only add operation if there are existing sources to merge
        if ($existingSourceTags.Count -gt 0) {
            $result.MergeOperations += @{
                TargetName         = $targetName
                TargetSlug         = $targetSlug
                SourceTags         = $item.mergeTags
                ExistingSourceTags = $existingSourceTags
                TargetExists       = $existingByName.ContainsKey($targetName.ToLower().Trim()) -or 
                                     $existingBySlug.ContainsKey($targetSlug.ToLower().Trim())
            }
        }
        elseif ($missingSourceTags.Count -eq $item.mergeTags.Count) {
            # All sources are missing - just a warning
            $result.Warnings += "Merge target '$targetName': No source tags exist, nothing to merge."
        }
    }
    
    return $result
}
