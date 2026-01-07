#Requires -Version 7.0
<#
.SYNOPSIS
    Import helper functions for MealieSync
.DESCRIPTION
    Internal helper functions for reading import files, creating backups,
    merging aliases, and performing pre-import validation.
.NOTES
    This is a private function file - not exported by the module.
#>

function Read-ImportFile {
    <#
    .SYNOPSIS
        Read and validate a JSON import file
    .DESCRIPTION
        Reads a JSON file, validates the type if using the new wrapper format,
        and returns the items array. Supports both new wrapper format and
        legacy raw array format for backward compatibility.
    .PARAMETER Path
        Path to the JSON file to read
    .PARAMETER ExpectedType
        The expected data type (Foods, Units, Labels, Categories, Tags, Tools)
    .PARAMETER ValidateHouseholds
        Perform upfront validation of household names
    .OUTPUTS
        [hashtable] @{ Items = [array]; IsNewFormat = [bool]; ValidationResult = [hashtable] }
    .EXAMPLE
        $result = Read-ImportFile -Path "Foods.json" -ExpectedType "Foods" -ValidateHouseholds
        if (-not $result.ValidationResult.Valid) {
            throw "Validation failed"
        }
        $items = $result.Items
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [ValidateSet('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools')]
        [string]$ExpectedType,
        
        [switch]$ValidateHouseholds
    )
    
    # Check file exists
    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }
    
    # Read and parse JSON
    try {
        $rawContent = Get-Content $Path -Raw -Encoding UTF8
        $data = $rawContent | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse JSON from '$Path': $_"
    }
    
    # Check for wrapper format
    $isNewFormat = Test-JsonWrapper -Data $data
    
    # Validate data using Confirm-ImportData
    $validationResult = Confirm-ImportData -Data $data -ExpectedType $ExpectedType -ValidateHouseholds:$ValidateHouseholds
    
    # Extract items
    $items = Get-JsonItems -Data $data
    
    return @{
        Items            = $items
        IsNewFormat      = $isNewFormat
        ValidationResult = $validationResult
    }
}

function Backup-BeforeImport {
    <#
    .SYNOPSIS
        Create a backup of current data before import
    .DESCRIPTION
        Exports current Mealie data to a timestamped backup file in the
        Exports folder. Uses the existing Export functions.
    .PARAMETER Type
        The data type to backup (Foods, Units, Labels, Categories, Tags, Tools)
    .PARAMETER Skip
        Skip the backup operation
    .PARAMETER BasePath
        Base path for the Exports folder (default: current directory)
    .OUTPUTS
        [string] Path to the backup file, or $null if skipped
    .EXAMPLE
        $backupPath = Backup-BeforeImport -Type "Foods"
        # Creates: Exports/AutoBackups/Backup_Foods_20260106_143052.json
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools')]
        [string]$Type,
        
        [switch]$Skip,
        
        [string]$BasePath = "."
    )
    
    if ($Skip) {
        Write-Verbose "Backup skipped (-SkipBackup specified)"
        return $null
    }
    
    # Create timestamp for unique filename
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFileName = "Backup_${Type}_${timestamp}.json"
    $backupDir = Join-Path $BasePath "Exports" "AutoBackups"
    $backupPath = Join-Path $backupDir $backupFileName
    
    # Ensure Exports/AutoBackups directory exists
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    
    try {
        # Fetch current data and create backup (sorted alphabetically)
        switch ($Type) {
            'Foods' {
                $items = Get-MealieFoods -All
                $exportItems = @($items | Sort-Object name | ForEach-Object { ConvertTo-FoodExport -Food $_ })
            }
            'Units' {
                $items = Get-MealieUnits -All
                $exportItems = @($items | Sort-Object name | ForEach-Object { ConvertTo-UnitExport -Unit $_ })
            }
            'Labels' {
                $items = Get-MealieLabels -All
                $exportItems = @($items | Sort-Object name | ForEach-Object { ConvertTo-LabelExport -Label $_ })
            }
            'Categories' {
                $items = Get-MealieCategories -All
                $exportItems = @($items | Sort-Object name | ForEach-Object { ConvertTo-OrganizerExport -Item $_ -Type 'Categories' })
            }
            'Tags' {
                $items = Get-MealieTags -All
                $exportItems = @($items | Sort-Object name | ForEach-Object { ConvertTo-OrganizerExport -Item $_ -Type 'Tags' })
            }
            'Tools' {
                $items = Get-MealieTools -All
                $exportItems = @($items | Sort-Object name | ForEach-Object { ConvertTo-OrganizerExport -Item $_ -Type 'Tools' })
            }
        }
        
        # Create wrapper and write file
        $wrapper = New-ExportWrapper -Type $Type -Items $exportItems
        $json = $wrapper | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($backupPath, $json, [System.Text.UTF8Encoding]::new($false))
        
        Write-Verbose "Backup created: $backupPath ($($exportItems.Count) items)"
        return $backupPath
    }
    catch {
        Write-Warning "Failed to create backup: $_"
        return $null
    }
}

function Merge-Aliases {
    <#
    .SYNOPSIS
        Merge or replace aliases from two sources
    .DESCRIPTION
        Combines aliases from existing and new items. In merge mode (default),
        combines both sets with deduplication. In replace mode, uses only the
        new aliases.
    .PARAMETER ExistingAliases
        Array of alias objects from the existing item
    .PARAMETER NewAliases
        Array of alias objects from the import data
    .PARAMETER ReplaceMode
        If true, replace existing aliases with new ones instead of merging
    .OUTPUTS
        [array] Array of merged alias names (strings)
    .EXAMPLE
        $merged = Merge-Aliases -ExistingAliases $food.aliases -NewAliases $item.aliases
        # Returns: @("alias1", "alias2", "alias3")
    .EXAMPLE
        $replaced = Merge-Aliases -ExistingAliases $food.aliases -NewAliases $item.aliases -ReplaceMode
        # Returns only new aliases
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [AllowNull()]
        [array]$ExistingAliases,
        
        [AllowNull()]
        [array]$NewAliases,
        
        [switch]$ReplaceMode
    )
    
    # Extract alias names from objects
    $existingNames = @()
    if ($ExistingAliases -and $ExistingAliases.Count -gt 0) {
        $existingNames = @($ExistingAliases | ForEach-Object { $_.name })
    }
    
    $newNames = @()
    if ($NewAliases -and $NewAliases.Count -gt 0) {
        $newNames = @($NewAliases | ForEach-Object { $_.name })
    }
    
    # In replace mode, just return new aliases (deduplicated)
    if ($ReplaceMode) {
        $result = @()
        $seenLower = @{}
        foreach ($alias in $newNames) {
            $lowerAlias = $alias.ToLower().Trim()
            if (-not $seenLower.ContainsKey($lowerAlias)) {
                $seenLower[$lowerAlias] = $true
                $result += $alias
            }
        }
        return $result
    }
    
    # Merge mode: combine and deduplicate (case-insensitive, preserve first occurrence's casing)
    $result = @()
    $seenLower = @{}
    
    # Add existing aliases first (preserves existing casing)
    foreach ($alias in $existingNames) {
        $lowerAlias = $alias.ToLower().Trim()
        if (-not $seenLower.ContainsKey($lowerAlias)) {
            $seenLower[$lowerAlias] = $true
            $result += $alias
        }
    }
    
    # Add new aliases (only if not already present)
    foreach ($alias in $newNames) {
        $lowerAlias = $alias.ToLower().Trim()
        if (-not $seenLower.ContainsKey($lowerAlias)) {
            $seenLower[$lowerAlias] = $true
            $result += $alias
        }
    }
    
    return $result
}

function Find-ExistingItem {
    <#
    .SYNOPSIS
        Find an existing item using multiple lookup strategies
    .DESCRIPTION
        Searches for an existing item using the provided lookup tables.
        Returns the matched item, method used, and the actual values that matched.
    .PARAMETER ImportItem
        The item from the import data
    .PARAMETER Lookups
        Hashtable with ById, ByName, and ByAlias lookup tables
    .PARAMETER IncludeAbbreviation
        Also check abbreviation/pluralAbbreviation (for units)
    .OUTPUTS
        [hashtable] @{ Item; MatchMethod; ImportValue; ExistingValue } or $null
    .EXAMPLE
        $match = Find-ExistingItem -ImportItem $item -Lookups $lookups
        if ($match) {
            $existingItem = $match.Item
            $matchMethod = $match.MatchMethod
            # $match.ImportValue = what from import matched
            # $match.ExistingValue = what on existing item it matched against
        }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object]$ImportItem,
        
        [Parameter(Mandatory)]
        [hashtable]$Lookups,
        
        [switch]$IncludeAbbreviation
    )
    
    $result = $null
    $matchMethod = $null
    
    # 1. Try match by id
    if ($ImportItem.id -and $Lookups.ById.ContainsKey($ImportItem.id)) {
        return @{
            Item          = $Lookups.ById[$ImportItem.id]
            MatchMethod   = "id"
            ImportValue   = $ImportItem.id
            ExistingValue = $ImportItem.id
        }
    }
    
    # 2. Try match by name
    $nameKey = $ImportItem.name.ToLower().Trim()
    if ($Lookups.ByName.ContainsKey($nameKey)) {
        $existing = $Lookups.ByName[$nameKey]
        if ($existing.name.ToLower().Trim() -eq $nameKey) {
            return @{
                Item          = $existing
                MatchMethod   = "name"
                ImportValue   = $ImportItem.name
                ExistingValue = $existing.name
            }
        }
        else {
            return @{
                Item          = $existing
                MatchMethod   = "name->pluralName"
                ImportValue   = $ImportItem.name
                ExistingValue = $existing.pluralName
            }
        }
    }
    
    # 3. Try match by pluralName
    if (![string]::IsNullOrEmpty($ImportItem.pluralName)) {
        $pluralKey = $ImportItem.pluralName.ToLower().Trim()
        if ($Lookups.ByName.ContainsKey($pluralKey)) {
            $existing = $Lookups.ByName[$pluralKey]
            if ($existing.name.ToLower().Trim() -eq $pluralKey) {
                return @{
                    Item          = $existing
                    MatchMethod   = "pluralName->name"
                    ImportValue   = $ImportItem.pluralName
                    ExistingValue = $existing.name
                }
            }
            else {
                return @{
                    Item          = $existing
                    MatchMethod   = "pluralName->pluralName"
                    ImportValue   = $ImportItem.pluralName
                    ExistingValue = $existing.pluralName
                }
            }
        }
        # Also check pluralName against aliases
        if ($Lookups.ByAlias.ContainsKey($pluralKey)) {
            $existing = $Lookups.ByAlias[$pluralKey]
            # Find which alias matched
            $matchedAlias = ($existing.aliases | Where-Object { $_.name.ToLower().Trim() -eq $pluralKey } | Select-Object -First 1).name
            return @{
                Item          = $existing
                MatchMethod   = "pluralName->alias"
                ImportValue   = $ImportItem.pluralName
                ExistingValue = $matchedAlias
            }
        }
    }
    
    # 4. Try match by abbreviation (units only)
    if ($IncludeAbbreviation) {
        if (![string]::IsNullOrEmpty($ImportItem.abbreviation)) {
            $abbrevKey = $ImportItem.abbreviation.ToLower().Trim()
            if ($Lookups.ByName.ContainsKey($abbrevKey)) {
                $existing = $Lookups.ByName[$abbrevKey]
                return @{
                    Item          = $existing
                    MatchMethod   = "abbreviation"
                    ImportValue   = $ImportItem.abbreviation
                    ExistingValue = $existing.abbreviation
                }
            }
        }
        if (![string]::IsNullOrEmpty($ImportItem.pluralAbbreviation)) {
            $pluralAbbrevKey = $ImportItem.pluralAbbreviation.ToLower().Trim()
            if ($Lookups.ByName.ContainsKey($pluralAbbrevKey)) {
                $existing = $Lookups.ByName[$pluralAbbrevKey]
                return @{
                    Item          = $existing
                    MatchMethod   = "pluralAbbreviation"
                    ImportValue   = $ImportItem.pluralAbbreviation
                    ExistingValue = $existing.pluralAbbreviation
                }
            }
        }
    }
    
    # 5. Try match by alias (import name -> existing alias)
    if ($Lookups.ByAlias.ContainsKey($nameKey)) {
        $existing = $Lookups.ByAlias[$nameKey]
        $matchedAlias = ($existing.aliases | Where-Object { $_.name.ToLower().Trim() -eq $nameKey } | Select-Object -First 1).name
        return @{
            Item          = $existing
            MatchMethod   = "name->alias"
            ImportValue   = $ImportItem.name
            ExistingValue = $matchedAlias
        }
    }
    
    # 6. Try match by import aliases -> existing name/pluralName/alias
    if ($ImportItem.aliases -and $ImportItem.aliases.Count -gt 0) {
        foreach ($alias in $ImportItem.aliases) {
            $aliasKey = $alias.name.ToLower().Trim()
            
            # Check against existing name/pluralName
            if ($Lookups.ByName.ContainsKey($aliasKey)) {
                $existing = $Lookups.ByName[$aliasKey]
                if ($existing.name.ToLower().Trim() -eq $aliasKey) {
                    return @{
                        Item          = $existing
                        MatchMethod   = "alias->name"
                        ImportValue   = $alias.name
                        ExistingValue = $existing.name
                    }
                }
                else {
                    return @{
                        Item          = $existing
                        MatchMethod   = "alias->pluralName"
                        ImportValue   = $alias.name
                        ExistingValue = $existing.pluralName
                    }
                }
            }
            
            # Check against existing aliases
            if ($Lookups.ByAlias.ContainsKey($aliasKey)) {
                $existing = $Lookups.ByAlias[$aliasKey]
                $matchedAlias = ($existing.aliases | Where-Object { $_.name.ToLower().Trim() -eq $aliasKey } | Select-Object -First 1).name
                return @{
                    Item          = $existing
                    MatchMethod   = "alias->alias"
                    ImportValue   = $alias.name
                    ExistingValue = $matchedAlias
                }
            }
        }
    }
    
    return $null
}

function Format-FoodChanges {
    <#
    .SYNOPSIS
        Build a list of changes between existing and new food items
    .DESCRIPTION
        Compares food properties and returns an array of change objects for display.
        Uses the same comparison logic as Test-FoodChanged for consistency.
    .PARAMETER Existing
        The existing food from the API
    .PARAMETER New
        The new food from import data
    .PARAMETER ResolvedLabelId
        The resolved label ID for the new food
    .PARAMETER MergedAliases
        Array of merged alias names
    .OUTPUTS
        [array] Array of @{ Field; Old; New } change objects
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New,
        
        [string]$ResolvedLabelId,
        
        [array]$MergedAliases
    )
    
    $changes = @()
    
    # Name change (use same comparison as Test-FoodChanged)
    if (-not (Compare-StringValue $Existing.name $New.name)) {
        $changes += @{ Field = "name"; Old = $Existing.name; New = $New.name.Trim() }
    }
    
    # PluralName change
    if (-not (Compare-StringValue $Existing.pluralName $New.pluralName)) {
        $oldVal = if ([string]::IsNullOrEmpty($Existing.pluralName)) { "(empty)" } else { $Existing.pluralName }
        $newVal = if ([string]::IsNullOrEmpty($New.pluralName)) { "(empty)" } else { $New.pluralName }
        $changes += @{ Field = "pluralName"; Old = $oldVal; New = $newVal }
    }
    
    # Description change (use same comparison as Test-FoodChanged)
    if (-not (Compare-StringValue $Existing.description $New.description)) {
        $oldVal = if ([string]::IsNullOrEmpty($Existing.description)) { "(empty)" } else { 
            if ($Existing.description.Length -gt 40) { $Existing.description.Substring(0, 40) + "..." } else { $Existing.description }
        }
        $newVal = if ([string]::IsNullOrEmpty($New.description)) { "(empty)" } else { 
            if ($New.description.Length -gt 40) { $New.description.Substring(0, 40) + "..." } else { $New.description }
        }
        $changes += @{ Field = "description"; Old = $oldVal; New = $newVal }
    }
    
    # Label change (use same comparison as Test-FoodChanged)
    if (-not (Compare-StringValue $Existing.labelId $ResolvedLabelId)) {
        $oldLabel = if ($Existing.label) { $Existing.label.name } else { "(none)" }
        $newLabel = if ($New.label) { $New.label } else { "(none)" }
        $changes += @{ Field = "label"; Old = $oldLabel; New = $newLabel }
    }
    
    # Alias change (use same comparison logic as Test-FoodChanged)
    $existingAliasNames = @()
    if ($Existing.aliases -and $Existing.aliases.Count -gt 0) {
        $existingAliasNames = @($Existing.aliases | ForEach-Object { $_.name.ToLower().Trim() }) | Sort-Object
    }
    
    $mergedAliasNamesLower = @()
    if ($MergedAliases -and $MergedAliases.Count -gt 0) {
        $mergedAliasNamesLower = @($MergedAliases | ForEach-Object { $_.ToLower().Trim() }) | Sort-Object
    }
    
    $existingStr = $existingAliasNames -join ","
    $mergedStr = $mergedAliasNamesLower -join ","
    
    # Use ordinal comparison for diacritics
    if (-not [string]::Equals($existingStr, $mergedStr, [StringComparison]::Ordinal)) {
        # Show original case for display
        $existingDisplay = if ($Existing.aliases -and $Existing.aliases.Count -gt 0) {
            ($Existing.aliases | ForEach-Object { $_.name }) -join ", "
        } else { "(none)" }
        $mergedDisplay = if ($MergedAliases -and $MergedAliases.Count -gt 0) {
            $MergedAliases -join ", "
        } else { "(none)" }
        $changes += @{ Field = "aliases"; Old = $existingDisplay; New = $mergedDisplay }
    }
    
    return $changes
}

function Format-UnitChanges {
    <#
    .SYNOPSIS
        Build a list of changes between existing and new unit items
    .DESCRIPTION
        Compares unit properties and returns an array of change objects for display.
    .PARAMETER Existing
        The existing unit from the API
    .PARAMETER New
        The new unit from import data
    .PARAMETER MergedAliases
        Array of merged alias names
    .OUTPUTS
        [array] Array of @{ Field; Old; New } change objects
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New,
        
        [array]$MergedAliases
    )
    
    $changes = @()
    
    # Basic fields
    $fields = @('name', 'pluralName', 'description', 'abbreviation', 'pluralAbbreviation')
    foreach ($field in $fields) {
        if (-not (Compare-StringValue $Existing.$field $New.$field)) {
            $oldVal = if ([string]::IsNullOrEmpty($Existing.$field)) { "" } else { $Existing.$field }
            $newVal = if ([string]::IsNullOrEmpty($New.$field)) { "" } else { $New.$field }
            if ($field -eq 'description' -and $newVal.Length -gt 40) {
                $newVal = $newVal.Substring(0, 40) + "..."
            }
            $changes += @{ Field = $field; Old = $oldVal; New = $newVal }
        }
    }
    
    # Boolean fields
    if ($null -ne $New.useAbbreviation -and $Existing.useAbbreviation -ne $New.useAbbreviation) {
        $changes += @{ Field = "useAbbreviation"; Old = $Existing.useAbbreviation.ToString(); New = $New.useAbbreviation.ToString() }
    }
    if ($null -ne $New.fraction -and $Existing.fraction -ne $New.fraction) {
        $changes += @{ Field = "fraction"; Old = $Existing.fraction.ToString(); New = $New.fraction.ToString() }
    }
    
    # Alias change (use ordinal comparison for diacritics)
    if ($MergedAliases) {
        $existingAliasNames = @()
        if ($Existing.aliases -and $Existing.aliases.Count -gt 0) {
            $existingAliasNames = @($Existing.aliases | ForEach-Object { $_.name })
        }
        
        $existingAliasStr = ($existingAliasNames | ForEach-Object { $_.ToLower().Trim() } | Sort-Object) -join ","
        $mergedAliasStr = ($MergedAliases | ForEach-Object { $_.ToLower().Trim() } | Sort-Object) -join ","
        
        if (-not [string]::Equals($existingAliasStr, $mergedAliasStr, [StringComparison]::Ordinal)) {
            $changes += @{ Field = "aliases"; Old = ($existingAliasNames -join ", "); New = ($MergedAliases -join ", ") }
        }
    }
    
    return $changes
}
