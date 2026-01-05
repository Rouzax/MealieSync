#Requires -Version 7.0
<#
.SYNOPSIS
    Mealie API Module for Foods and Units management
.DESCRIPTION
    Provides functions to interact with the Mealie API for managing Foods and Units data.
    Supports creating, updating, and syncing data from JSON exports.
#>

# Module-level configuration
$script:MealieConfig = @{
    BaseUrl = $null
    Token   = $null
    Headers = $null
}

function Initialize-MealieApi {
    <#
    .SYNOPSIS
        Initialize the Mealie API connection
    .PARAMETER BaseUrl
        The base URL of your Mealie instance (e.g., http://localhost:9000)
    .PARAMETER Token
        Your Mealie API token (from /user/profile/api-tokens)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory)]
        [string]$Token
    )
    
    # Normalize URL (remove trailing slash)
    $script:MealieConfig.BaseUrl = $BaseUrl.TrimEnd('/')
    $script:MealieConfig.Token = $Token
    $script:MealieConfig.Headers = @{
        'Authorization' = "Bearer $Token"
        'Content-Type'  = 'application/json; charset=utf-8'
        'Accept'        = 'application/json'
    }
    
    # Test connection
    try {
        $response = Invoke-MealieRequest -Endpoint '/api/users/self' -Method 'GET'
        Write-Host "OK: Connected to Mealie as: $($response.username)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to connect to Mealie: $_"
        return $false
    }
}

#region Comparison Helper Functions

function Compare-Aliases {
    <#
    .SYNOPSIS
        Compare two alias arrays for equality
    #>
    param(
        [array]$Existing,
        [array]$New
    )
    
    # Normalize to arrays of names
    $existingNames = @()
    if ($Existing) {
        $existingNames = @($Existing | ForEach-Object { $_.name.ToLower().Trim() } | Sort-Object)
    }
    
    $newNames = @()
    if ($New) {
        $newNames = @($New | ForEach-Object { $_.name.ToLower().Trim() } | Sort-Object)
    }
    
    # Compare counts first
    if ($existingNames.Count -ne $newNames.Count) {
        return $false
    }
    
    # Compare each element
    for ($i = 0; $i -lt $existingNames.Count; $i++) {
        if ($existingNames[$i] -ne $newNames[$i]) {
            return $false
        }
    }
    
    return $true
}

function Compare-StringValue {
    <#
    .SYNOPSIS
        Compare two string values, treating null and empty as equal
    #>
    param(
        [string]$Existing,
        [string]$New
    )
    
    $existingNorm = if ([string]::IsNullOrEmpty($Existing)) { "" } else { $Existing.Trim() }
    $newNorm = if ([string]::IsNullOrEmpty($New)) { "" } else { $New.Trim() }
    
    return $existingNorm -eq $newNorm
}

function Test-FoodChanged {
    <#
    .SYNOPSIS
        Check if a food item has changes compared to existing data
    .PARAMETER ResolvedLabelId
        The resolved labelId from the import data (after name lookup)
    .NOTES
        For aliases, we compare the MERGED result (existing + new) against existing.
        This means if import has empty aliases, nothing changes (existing aliases are kept).
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New,
        
        [string]$ResolvedLabelId
    )
    
    # Compare name
    if (-not (Compare-StringValue $Existing.name $New.name)) { return $true }
    
    # Compare pluralName
    if (-not (Compare-StringValue $Existing.pluralName $New.pluralName)) { return $true }
    
    # Compare description
    if (-not (Compare-StringValue $Existing.description $New.description)) { return $true }
    
    # Compare labelId (existing labelId vs resolved labelId from import)
    if (-not (Compare-StringValue $Existing.labelId $ResolvedLabelId)) { return $true }
    
    # Compare aliases using merge logic (existing + new, deduplicated)
    $existingAliasNames = @()
    if ($Existing.aliases -and $Existing.aliases.Count -gt 0) {
        $existingAliasNames = @($Existing.aliases | ForEach-Object { $_.name.ToLower().Trim() }) | Sort-Object
    }
    $newAliasNames = @()
    if ($New.aliases -and $New.aliases.Count -gt 0) {
        $newAliasNames = @($New.aliases | ForEach-Object { $_.name.ToLower().Trim() })
    }
    
    # Merge and deduplicate
    $mergedAliases = @($existingAliasNames + $newAliasNames | Select-Object -Unique | Sort-Object)
    
    # If merged result differs from existing, there's a change
    $existingStr = $existingAliasNames -join ","
    $mergedStr = $mergedAliases -join ","
    if ($existingStr -ne $mergedStr) { return $true }
    
    return $false
}

function Test-UnitChanged {
    <#
    .SYNOPSIS
        Check if a unit item has changes compared to existing data
    .PARAMETER MergedAliases
        Pre-computed merged aliases array (existing + new, deduplicated)
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New,
        
        [array]$MergedAliases
    )
    
    # Compare string fields
    if (-not (Compare-StringValue $Existing.name $New.name)) { return $true }
    if (-not (Compare-StringValue $Existing.pluralName $New.pluralName)) { return $true }
    if (-not (Compare-StringValue $Existing.description $New.description)) { return $true }
    if (-not (Compare-StringValue $Existing.abbreviation $New.abbreviation)) { return $true }
    if (-not (Compare-StringValue $Existing.pluralAbbreviation $New.pluralAbbreviation)) { return $true }
    
    # Compare boolean fields
    $existingUseAbbr = if ($null -eq $Existing.useAbbreviation) { $false } else { [bool]$Existing.useAbbreviation }
    $newUseAbbr = if ($null -eq $New.useAbbreviation) { $false } else { [bool]$New.useAbbreviation }
    if ($existingUseAbbr -ne $newUseAbbr) { return $true }
    
    $existingFraction = if ($null -eq $Existing.fraction) { $true } else { [bool]$Existing.fraction }
    $newFraction = if ($null -eq $New.fraction) { $true } else { [bool]$New.fraction }
    if ($existingFraction -ne $newFraction) { return $true }
    
    # Compare aliases using merge logic
    $existingAliasNames = @()
    if ($Existing.aliases -and $Existing.aliases.Count -gt 0) {
        $existingAliasNames = @($Existing.aliases | ForEach-Object { $_.name.ToLower().Trim() }) | Sort-Object
    }
    
    $mergedAliasLower = @()
    if ($MergedAliases -and $MergedAliases.Count -gt 0) {
        $mergedAliasLower = @($MergedAliases | ForEach-Object { $_.ToLower().Trim() }) | Sort-Object
    }
    
    $existingStr = $existingAliasNames -join ","
    $mergedStr = $mergedAliasLower -join ","
    if ($existingStr -ne $mergedStr) { return $true }
    
    return $false
}

function Test-LabelChanged {
    <#
    .SYNOPSIS
        Check if a label has changes compared to existing data
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New
    )
    
    if (-not (Compare-StringValue $Existing.name $New.name)) { return $true }
    if (-not (Compare-StringValue $Existing.color $New.color)) { return $true }
    
    return $false
}

function Test-OrganizerChanged {
    <#
    .SYNOPSIS
        Check if a category/tag/tool has changes compared to existing data
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New
    )
    
    # Only name matters for organizers
    if (-not (Compare-StringValue $Existing.name $New.name)) { return $true }
    
    return $false
}

#endregion

function Invoke-MealieRequest {
    <#
    .SYNOPSIS
        Internal function to make API requests
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,
        
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string]$Method = 'GET',
        
        [object]$Body = $null
    )
    
    if (-not $script:MealieConfig.BaseUrl) {
        throw "Mealie API not initialized. Call Initialize-MealieApi first."
    }
    
    $uri = "$($script:MealieConfig.BaseUrl)$Endpoint"
    $params = @{
        Uri         = $uri
        Method      = $Method
        Headers     = $script:MealieConfig.Headers
        ErrorAction = 'Stop'
    }
    
    if ($Body -and $Method -in @('POST', 'PUT')) {
        $jsonBody = $Body | ConvertTo-Json -Depth 10 -Compress
        # Ensure UTF-8 encoding
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
    }
    
    try {
        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        $errorMessage = $_.ErrorDetails.Message
        
        if ($errorMessage) {
            # Try to parse JSON error response
            $detailMsg = $errorMessage
            try {
                $errorObj = $errorMessage | ConvertFrom-Json -ErrorAction Stop
                if ($errorObj.detail.message) {
                    $detailMsg = $errorObj.detail.message
                }
                elseif ($errorObj.detail -and $errorObj.detail -is [string]) {
                    $detailMsg = $errorObj.detail
                }
            }
            catch {
                # JSON parsing failed, use raw message
            }
            
            if ($statusCode) {
                throw "API Error ($statusCode): $detailMsg"
            }
            else {
                throw "API Error: $detailMsg"
            }
        }
        throw $_
    }
}

#region Foods Functions

function Get-MealieFoods {
    <#
    .SYNOPSIS
        Get all foods from Mealie
    .PARAMETER All
        Retrieve all foods (handles pagination)
    #>
    [CmdletBinding()]
    param(
        [switch]$All
    )
    
    $foods = @()
    $page = 1
    $perPage = 100
    
    do {
        $response = Invoke-MealieRequest -Endpoint "/api/foods?page=$page`&perPage=$perPage" -Method 'GET'
        $foods += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $foods
}

function New-MealieFood {
    <#
    .SYNOPSIS
        Create a new food in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$PluralName,
        [string]$Description,
        [array]$Aliases = @(),
        [string]$LabelId
    )
    
    $body = @{
        name = $Name
    }
    
    if (![string]::IsNullOrEmpty($Description)) {
        $body.description = $Description
    }
    if (![string]::IsNullOrEmpty($PluralName)) {
        $body.pluralName = $PluralName
    }
    if (![string]::IsNullOrEmpty($LabelId)) {
        $body.labelId = $LabelId
    }
    if ($Aliases -and $Aliases.Count -gt 0) {
        $body.aliases = @($Aliases | ForEach-Object { @{ name = $_ } })
    }
    
    return Invoke-MealieRequest -Endpoint '/api/foods' -Method 'POST' -Body $body
}

function Update-MealieFood {
    <#
    .SYNOPSIS
        Update an existing food in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [hashtable]$Data
    )
    
    # Build update body - only include non-null values
    $body = @{
        id = $Id
    }
    
    foreach ($key in $Data.Keys) {
        if ($null -ne $Data[$key]) {
            $body[$key] = $Data[$key]
        }
    }
    
    return Invoke-MealieRequest -Endpoint "/api/foods/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieFood {
    <#
    .SYNOPSIS
        Delete a food from Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/foods/$Id" -Method 'DELETE'
}

#endregion

#region Units Functions

function Get-MealieUnits {
    <#
    .SYNOPSIS
        Get all units from Mealie
    #>
    [CmdletBinding()]
    param(
        [switch]$All
    )
    
    $units = @()
    $page = 1
    $perPage = 100
    
    do {
        $response = Invoke-MealieRequest -Endpoint "/api/units?page=$page`&perPage=$perPage" -Method 'GET'
        $units += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $units
}

function New-MealieUnit {
    <#
    .SYNOPSIS
        Create a new unit in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$PluralName,
        [string]$Description,
        [string]$Abbreviation,
        [string]$PluralAbbreviation,
        [bool]$UseAbbreviation = $false,
        [bool]$Fraction = $true,
        [array]$Aliases = @()
    )
    
    $body = @{
        name            = $Name
        useAbbreviation = $UseAbbreviation
        fraction        = $Fraction
    }
    
    if (![string]::IsNullOrEmpty($Description)) {
        $body.description = $Description
    }
    if (![string]::IsNullOrEmpty($PluralName)) {
        $body.pluralName = $PluralName
    }
    if (![string]::IsNullOrEmpty($Abbreviation)) {
        $body.abbreviation = $Abbreviation
    }
    if (![string]::IsNullOrEmpty($PluralAbbreviation)) {
        $body.pluralAbbreviation = $PluralAbbreviation
    }
    if ($Aliases -and $Aliases.Count -gt 0) {
        $body.aliases = @($Aliases | ForEach-Object { @{ name = $_ } })
    }
    
    return Invoke-MealieRequest -Endpoint '/api/units' -Method 'POST' -Body $body
}

function Update-MealieUnit {
    <#
    .SYNOPSIS
        Update an existing unit in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [hashtable]$Data
    )
    
    $body = @{
        id = $Id
    }
    
    foreach ($key in $Data.Keys) {
        if ($null -ne $Data[$key]) {
            $body[$key] = $Data[$key]
        }
    }
    
    return Invoke-MealieRequest -Endpoint "/api/units/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieUnit {
    <#
    .SYNOPSIS
        Delete a unit from Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/units/$Id" -Method 'DELETE'
}

#endregion

#region Import/Sync Functions

function Import-MealieFoods {
    <#
    .SYNOPSIS
        Import foods from a JSON file, creating new or updating existing
    .PARAMETER Path
        Path to the JSON file containing food data
    .PARAMETER UpdateExisting
        Update foods that already exist (matched by id, name, pluralName, or alias)
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER MatchedIds
        Hashtable tracking already-matched item IDs (for cross-file conflict detection in folder imports)
    .PARAMETER WhatIf
        Show what would happen without making changes
    .NOTES
        Matching order (prevents duplicates when renaming):
        1) id
        2) name/pluralName (all cross-combinations)
        3) alias (all cross-combinations including alias->alias)
        
        Supports 'label' field in JSON (label name). The label must already exist in Mealie.
        If a label name is not found, a warning is shown and the food is imported without label.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$UpdateExisting,
        
        [int]$ThrottleMs = 100,
        
        [hashtable]$MatchedIds
    )
    
    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }
    
    $importData = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $existingFoods = Get-MealieFoods -All
    
    # Fetch labels and create lookup by name (case-insensitive)
    $existingLabels = Get-MealieLabels -All
    $labelsByName = @{}
    foreach ($label in $existingLabels) {
        $labelsByName[$label.name.ToLower().Trim()] = $label
    }
    
    # Create multiple lookups for Optie C matching
    $existingById = @{}
    $existingByName = @{}      # Also includes pluralName
    $existingByAlias = @{}
    
    foreach ($food in $existingFoods) {
        # Lookup by id
        $existingById[$food.id] = $food
        
        # Lookup by name (case-insensitive)
        $existingByName[$food.name.ToLower().Trim()] = $food
        
        # Lookup by pluralName (case-insensitive) - enables matching "braam" -> "bramen"
        if (![string]::IsNullOrEmpty($food.pluralName)) {
            $pluralKey = $food.pluralName.ToLower().Trim()
            if (-not $existingByName.ContainsKey($pluralKey)) {
                $existingByName[$pluralKey] = $food
            }
        }
        
        # Lookup by alias (case-insensitive)
        if ($food.aliases -and $food.aliases.Count -gt 0) {
            foreach ($alias in $food.aliases) {
                $aliasKey = $alias.name.ToLower().Trim()
                if (-not $existingByAlias.ContainsKey($aliasKey)) {
                    $existingByAlias[$aliasKey] = $food
                }
            }
        }
    }
    
    $stats = @{
        Created       = 0
        Updated       = 0
        Unchanged     = 0
        Skipped       = 0
        Errors        = 0
        LabelWarnings = 0
        Conflicts     = 0
    }
    
    $total = @($importData).Count
    $padWidth = $total.ToString().Length
    $current = 0
    
    # Use provided MatchedIds or create new (for cross-file conflict detection)
    if (-not $MatchedIds) {
        $MatchedIds = @{}
    }
    
    foreach ($item in $importData) {
        $current++
        $counter = "[$($current.ToString().PadLeft($padWidth))/$total]"
        $itemName = $item.name.Trim()
        
        # Progress indicator
        $percentComplete = [math]::Round(($current / $total) * 100)
        Write-Progress -Activity "Importing Foods" -Status "$current of $total - $itemName" -PercentComplete $percentComplete
        
        # Matching order: id -> name/pluralName (all combos) -> alias (all combos)
        $existingFood = $null
        $matchMethod = $null
        
        # 1. Try match by id (if present in import data)
        if ($item.id -and $existingById.ContainsKey($item.id)) {
            $existingFood = $existingById[$item.id]
            $matchMethod = "id"
        }
        
        # 2. Try match by name or pluralName (both directions)
        if (-not $existingFood) {
            # Check import.name against existing name/pluralName
            $nameKey = $itemName.ToLower()
            if ($existingByName.ContainsKey($nameKey)) {
                $existingFood = $existingByName[$nameKey]
                # Check if it matched on name or pluralName
                if ($existingFood.name.ToLower().Trim() -eq $nameKey) {
                    $matchMethod = "name"
                }
                else {
                    $matchMethod = "name->pluralName"
                }
            }
        }
        
        # 2b. Check import.pluralName against existing name/pluralName
        if (-not $existingFood -and ![string]::IsNullOrEmpty($item.pluralName)) {
            $pluralKey = $item.pluralName.ToLower().Trim()
            if ($existingByName.ContainsKey($pluralKey)) {
                $existingFood = $existingByName[$pluralKey]
                # Check if it matched on name or pluralName
                if ($existingFood.name.ToLower().Trim() -eq $pluralKey) {
                    $matchMethod = "pluralName->name"
                }
                else {
                    $matchMethod = "pluralName"
                }
            }
        }
        
        # 2c. Check import.pluralName against existing aliases
        if (-not $existingFood -and ![string]::IsNullOrEmpty($item.pluralName)) {
            $pluralKey = $item.pluralName.ToLower().Trim()
            if ($existingByAlias.ContainsKey($pluralKey)) {
                $existingFood = $existingByAlias[$pluralKey]
                $matchMethod = "pluralName->alias"
            }
        }
        
        # 3. Try match by alias (all directions):
        #    - import.name -> existing.alias
        #    - import.alias -> existing.name/pluralName
        #    - import.alias -> existing.alias
        if (-not $existingFood) {
            # Check if new name is an existing alias
            $nameKey = $itemName.ToLower()
            if ($existingByAlias.ContainsKey($nameKey)) {
                $existingFood = $existingByAlias[$nameKey]
                $matchMethod = "name->alias"
            }
            
            # Check if any new aliases match existing names, pluralNames, or aliases
            if (-not $existingFood -and $item.aliases -and $item.aliases.Count -gt 0) {
                foreach ($alias in $item.aliases) {
                    $aliasKey = $alias.name.ToLower().Trim()
                    
                    # Check against existing name/pluralName
                    if ($existingByName.ContainsKey($aliasKey)) {
                        $existingFood = $existingByName[$aliasKey]
                        if ($existingFood.name.ToLower().Trim() -eq $aliasKey) {
                            $matchMethod = "alias->name"
                        }
                        else {
                            $matchMethod = "alias->pluralName"
                        }
                        break
                    }
                    
                    # Check against existing aliases
                    if ($existingByAlias.ContainsKey($aliasKey)) {
                        $existingFood = $existingByAlias[$aliasKey]
                        $matchMethod = "alias->alias"
                        break
                    }
                }
            }
        }
        
        # Check for conflict: has this existing item already been matched by another import item?
        if ($existingFood -and $MatchedIds.ContainsKey($existingFood.id)) {
            $previousMatch = $MatchedIds[$existingFood.id]
            Write-Warning "  $counter CONFLICT: '$itemName' matches existing '$($existingFood.name)' (via $matchMethod), but it was already matched by '$previousMatch'"
            $stats.Conflicts++
            continue
        }
        
        # Track this match
        if ($existingFood) {
            $MatchedIds[$existingFood.id] = $itemName
        }
        
        # Resolve label name to labelId
        $resolvedLabelId = $null
        if (![string]::IsNullOrEmpty($item.label)) {
            $labelLookup = $labelsByName[$item.label.ToLower().Trim()]
            if ($labelLookup) {
                $resolvedLabelId = $labelLookup.id
            }
            else {
                Write-Warning "  $counter Label not found: '$($item.label)' for food '$itemName'"
                $stats.LabelWarnings++
            }
        }
        
        try {
            if ($existingFood) {
                if ($UpdateExisting) {
                    # Check if anything actually changed (including label)
                    if (-not (Test-FoodChanged -Existing $existingFood -New $item -ResolvedLabelId $resolvedLabelId)) {
                        Write-Verbose "  $counter Unchanged: $itemName"
                        $stats.Unchanged++
                        continue
                    }
                    
                    # Build change list for display
                    $changes = @()
                    if ($existingFood.name -ne $itemName) {
                        $changes += @{ Field = "name"; Old = $existingFood.name; New = $itemName }
                    }
                    if ($existingFood.pluralName -ne $item.pluralName) {
                        $changes += @{ Field = "pluralName"; Old = $existingFood.pluralName; New = $item.pluralName }
                    }
                    if ($existingFood.description -ne $item.description -and ![string]::IsNullOrEmpty($item.description)) {
                        $descPreview = if ($item.description.Length -gt 40) { $item.description.Substring(0,40) + "..." } else { $item.description }
                        $changes += @{ Field = "description"; Old = ""; New = $descPreview }
                    }
                    if ($existingFood.labelId -ne $resolvedLabelId) {
                        $oldLabel = if ($existingFood.label) { $existingFood.label.name } else { "(none)" }
                        $newLabel = if ($item.label) { $item.label } else { "(none)" }
                        $changes += @{ Field = "label"; Old = $oldLabel; New = $newLabel }
                    }
                    
                    # Merge aliases: combine existing + new, deduplicate (case-insensitive)
                    $existingAliasNames = @()
                    if ($existingFood.aliases -and $existingFood.aliases.Count -gt 0) {
                        $existingAliasNames = @($existingFood.aliases | ForEach-Object { $_.name })
                    }
                    $newAliasNames = @()
                    if ($item.aliases -and $item.aliases.Count -gt 0) {
                        $newAliasNames = @($item.aliases | ForEach-Object { $_.name })
                    }
                    
                    # Merge and deduplicate (case-insensitive, preserve first occurrence's casing)
                    $mergedAliases = @()
                    $seenLower = @{}
                    foreach ($alias in ($existingAliasNames + $newAliasNames)) {
                        $lowerAlias = $alias.ToLower().Trim()
                        if (-not $seenLower.ContainsKey($lowerAlias)) {
                            $seenLower[$lowerAlias] = $true
                            $mergedAliases += $alias
                        }
                    }
                    
                    # Check if merged result differs from existing
                    $existingAliasStr = ($existingAliasNames | Sort-Object) -join ", "
                    $mergedAliasStr = ($mergedAliases | Sort-Object) -join ", "
                    if ($existingAliasStr -ne $mergedAliasStr) {
                        $changes += @{ Field = "aliases"; Old = ($existingAliasNames -join ", "); New = ($mergedAliases -join ", ") }
                    }
                    
                    if ($WhatIfPreference) {
                        # Custom formatted WhatIf output
                        Write-Host "  $counter " -NoNewline
                        Write-Host "Would UPDATE " -ForegroundColor Yellow -NoNewline
                        Write-Host "(matched by $matchMethod): " -NoNewline
                        Write-Host "$itemName" -ForegroundColor Cyan
                        foreach ($change in $changes) {
                            $oldVal = if ([string]::IsNullOrEmpty($change.Old)) { "(empty)" } else { $change.Old }
                            $newVal = if ([string]::IsNullOrEmpty($change.New)) { "(empty)" } else { $change.New }
                            Write-Host "          $($change.Field.PadRight(12)): " -NoNewline
                            Write-Host "'$oldVal'" -ForegroundColor Red -NoNewline
                            Write-Host " -> " -NoNewline
                            Write-Host "'$newVal'" -ForegroundColor Green
                        }
                        $stats.Updated++
                    }
                    elseif ($PSCmdlet.ShouldProcess($itemName, "Update food")) {
                        # Use merged aliases
                        $aliases = @($mergedAliases | ForEach-Object { @{ name = $_ } })
                        
                        # Only include non-null, non-empty values
                        $updateData = @{
                            name = $itemName
                        }
                        
                        if (![string]::IsNullOrEmpty($item.pluralName)) {
                            $updateData.pluralName = $item.pluralName
                        }
                        if (![string]::IsNullOrEmpty($item.description)) {
                            $updateData.description = $item.description
                        }
                        if ($aliases.Count -gt 0) {
                            $updateData.aliases = $aliases
                        }
                        if ($resolvedLabelId) {
                            $updateData.labelId = $resolvedLabelId
                        }
                        
                        Update-MealieFood -Id $existingFood.id -Data $updateData | Out-Null
                        Write-Host "  $counter Updated (matched by $matchMethod): $itemName" -ForegroundColor Yellow
                        $stats.Updated++
                        
                        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                    }
                }
                else {
                    Write-Verbose "  $counter Skipped (exists, matched by $matchMethod): $itemName"
                    $stats.Skipped++
                }
            }
            else {
                if ($WhatIfPreference) {
                    # Custom formatted WhatIf output for Create
                    Write-Host "  $counter " -NoNewline
                    Write-Host "Would CREATE" -ForegroundColor Green -NoNewline
                    Write-Host ": " -NoNewline
                    Write-Host "$itemName" -ForegroundColor Cyan
                    if (![string]::IsNullOrEmpty($item.pluralName)) {
                        Write-Host "          pluralName   : " -NoNewline
                        Write-Host "'$($item.pluralName)'" -ForegroundColor Green
                    }
                    if (![string]::IsNullOrEmpty($item.description)) {
                        $descPreview = if ($item.description.Length -gt 40) { $item.description.Substring(0,40) + "..." } else { $item.description }
                        Write-Host "          description  : " -NoNewline
                        Write-Host "'$descPreview'" -ForegroundColor Green
                    }
                    if (![string]::IsNullOrEmpty($item.label)) {
                        Write-Host "          label        : " -NoNewline
                        Write-Host "'$($item.label)'" -ForegroundColor Green
                    }
                    if ($item.aliases -and $item.aliases.Count -gt 0) {
                        $aliasStr = ($item.aliases | ForEach-Object { $_.name }) -join ", "
                        Write-Host "          aliases      : " -NoNewline
                        Write-Host "'$aliasStr'" -ForegroundColor Green
                    }
                    $stats.Created++
                }
                elseif ($PSCmdlet.ShouldProcess($itemName, "Create food")) {
                    $aliasNames = @()
                    if ($item.aliases -and @($item.aliases).Count -gt 0) {
                        $aliasNames = @($item.aliases | ForEach-Object { $_.name })
                    }
                    
                    $params = @{
                        Name = $itemName
                    }
                    if (![string]::IsNullOrEmpty($item.pluralName)) {
                        $params.PluralName = $item.pluralName
                    }
                    if (![string]::IsNullOrEmpty($item.description)) {
                        $params.Description = $item.description
                    }
                    if ($aliasNames.Count -gt 0) {
                        $params.Aliases = $aliasNames
                    }
                    if ($resolvedLabelId) {
                        $params.LabelId = $resolvedLabelId
                    }
                    
                    New-MealieFood @params | Out-Null
                    Write-Host "  $counter Created: $itemName" -ForegroundColor Green
                    $stats.Created++
                    
                    if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                }
            }
        }
        catch {
            Write-Warning "  $counter Error processing '$itemName': $_"
            $stats.Errors++
        }
    }
    
    Write-Progress -Activity "Importing Foods" -Completed
    
    Write-Host "`nImport Summary:" -ForegroundColor Cyan
    Write-Host "  Created:       $($stats.Created)"
    Write-Host "  Updated:       $($stats.Updated)"
    Write-Host "  Unchanged:     $($stats.Unchanged)"
    Write-Host "  Skipped:       $($stats.Skipped)"
    Write-Host "  Errors:        $($stats.Errors)"
    if ($stats.LabelWarnings -gt 0) {
        Write-Host "  LabelWarnings: $($stats.LabelWarnings)" -ForegroundColor Yellow
    }
    if ($stats.Conflicts -gt 0) {
        Write-Host "  Conflicts:     $($stats.Conflicts)" -ForegroundColor Red
    }
    
    return $stats
}

function Import-MealieUnits {
    <#
    .SYNOPSIS
        Import units from a JSON file, creating new or updating existing
    .PARAMETER Path
        Path to the JSON file containing unit data
    .PARAMETER UpdateExisting
        Update units that already exist (matched by id, name, pluralName, abbreviation, or alias)
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER MatchedIds
        Hashtable tracking already-matched item IDs (for cross-file conflict detection)
    .PARAMETER WhatIf
        Show what would happen without making changes
    .NOTES
        Matching order (prevents duplicates when renaming):
        1) id
        2) name/pluralName/abbreviation/pluralAbbreviation (all cross-combinations)
        3) alias (all cross-combinations)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$UpdateExisting,
        
        [int]$ThrottleMs = 100,
        
        [hashtable]$MatchedIds
    )
    
    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }
    
    $importData = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $existingUnits = Get-MealieUnits -All
    
    # Create multiple lookups for matching
    $existingById = @{}
    $existingByName = @{}      # name, pluralName, abbreviation, pluralAbbreviation
    $existingByAlias = @{}
    
    foreach ($unit in $existingUnits) {
        # Lookup by id
        $existingById[$unit.id] = $unit
        
        # Lookup by name (case-insensitive)
        $existingByName[$unit.name.ToLower().Trim()] = $unit
        
        # Lookup by pluralName
        if (![string]::IsNullOrEmpty($unit.pluralName)) {
            $pluralKey = $unit.pluralName.ToLower().Trim()
            if (-not $existingByName.ContainsKey($pluralKey)) {
                $existingByName[$pluralKey] = $unit
            }
        }
        
        # Lookup by abbreviation
        if (![string]::IsNullOrEmpty($unit.abbreviation)) {
            $abbrevKey = $unit.abbreviation.ToLower().Trim()
            if (-not $existingByName.ContainsKey($abbrevKey)) {
                $existingByName[$abbrevKey] = $unit
            }
        }
        
        # Lookup by pluralAbbreviation
        if (![string]::IsNullOrEmpty($unit.pluralAbbreviation)) {
            $pluralAbbrevKey = $unit.pluralAbbreviation.ToLower().Trim()
            if (-not $existingByName.ContainsKey($pluralAbbrevKey)) {
                $existingByName[$pluralAbbrevKey] = $unit
            }
        }
        
        # Lookup by aliases
        if ($unit.aliases -and $unit.aliases.Count -gt 0) {
            foreach ($alias in $unit.aliases) {
                $aliasKey = $alias.name.ToLower().Trim()
                if (-not $existingByAlias.ContainsKey($aliasKey)) {
                    $existingByAlias[$aliasKey] = $unit
                }
            }
        }
    }
    
    $stats = @{
        Created   = 0
        Updated   = 0
        Unchanged = 0
        Skipped   = 0
        Errors    = 0
        Conflicts = 0
    }
    
    $total = @($importData).Count
    $padWidth = $total.ToString().Length
    $current = 0
    
    # Use provided MatchedIds or create new
    if (-not $MatchedIds) {
        $MatchedIds = @{}
    }
    
    foreach ($item in $importData) {
        $current++
        $counter = "[$($current.ToString().PadLeft($padWidth))/$total]"
        $itemName = $item.name.Trim()
        
        # Progress indicator
        $percentComplete = [math]::Round(($current / $total) * 100)
        Write-Progress -Activity "Importing Units" -Status "$current of $total - $itemName" -PercentComplete $percentComplete
        
        # Matching order: id -> name/pluralName/abbreviation -> alias
        $existingUnit = $null
        $matchMethod = $null
        
        # 1. Try match by id
        if ($item.id -and $existingById.ContainsKey($item.id)) {
            $existingUnit = $existingById[$item.id]
            $matchMethod = "id"
        }
        
        # 2. Try match by name
        if (-not $existingUnit) {
            $nameKey = $itemName.ToLower()
            if ($existingByName.ContainsKey($nameKey)) {
                $existingUnit = $existingByName[$nameKey]
                $matchMethod = "name"
            }
        }
        
        # 2b. Try match by import pluralName
        if (-not $existingUnit -and ![string]::IsNullOrEmpty($item.pluralName)) {
            $pluralKey = $item.pluralName.ToLower().Trim()
            if ($existingByName.ContainsKey($pluralKey)) {
                $existingUnit = $existingByName[$pluralKey]
                $matchMethod = "pluralName"
            }
        }
        
        # 2c. Try match by import abbreviation
        if (-not $existingUnit -and ![string]::IsNullOrEmpty($item.abbreviation)) {
            $abbrevKey = $item.abbreviation.ToLower().Trim()
            if ($existingByName.ContainsKey($abbrevKey)) {
                $existingUnit = $existingByName[$abbrevKey]
                $matchMethod = "abbreviation"
            }
        }
        
        # 2d. Try match by import pluralAbbreviation
        if (-not $existingUnit -and ![string]::IsNullOrEmpty($item.pluralAbbreviation)) {
            $pluralAbbrevKey = $item.pluralAbbreviation.ToLower().Trim()
            if ($existingByName.ContainsKey($pluralAbbrevKey)) {
                $existingUnit = $existingByName[$pluralAbbrevKey]
                $matchMethod = "pluralAbbreviation"
            }
        }
        
        # 3. Try match by alias
        if (-not $existingUnit) {
            # Check if import name is an existing alias
            $nameKey = $itemName.ToLower()
            if ($existingByAlias.ContainsKey($nameKey)) {
                $existingUnit = $existingByAlias[$nameKey]
                $matchMethod = "name->alias"
            }
            
            # Check if any import aliases match existing
            if (-not $existingUnit -and $item.aliases -and $item.aliases.Count -gt 0) {
                foreach ($alias in $item.aliases) {
                    $aliasKey = $alias.name.ToLower().Trim()
                    if ($existingByName.ContainsKey($aliasKey)) {
                        $existingUnit = $existingByName[$aliasKey]
                        $matchMethod = "alias->name"
                        break
                    }
                    if ($existingByAlias.ContainsKey($aliasKey)) {
                        $existingUnit = $existingByAlias[$aliasKey]
                        $matchMethod = "alias->alias"
                        break
                    }
                }
            }
        }
        
        # Check for conflict
        if ($existingUnit -and $MatchedIds.ContainsKey($existingUnit.id)) {
            $previousMatch = $MatchedIds[$existingUnit.id]
            Write-Warning "  $counter CONFLICT: '$itemName' matches existing '$($existingUnit.name)' (via $matchMethod), but it was already matched by '$previousMatch'"
            $stats.Conflicts++
            continue
        }
        
        # Track this match
        if ($existingUnit) {
            $MatchedIds[$existingUnit.id] = $itemName
        }
        
        try {
            if ($existingUnit) {
                if ($UpdateExisting) {
                    # Merge aliases
                    $existingAliasNames = @()
                    if ($existingUnit.aliases -and $existingUnit.aliases.Count -gt 0) {
                        $existingAliasNames = @($existingUnit.aliases | ForEach-Object { $_.name })
                    }
                    $newAliasNames = @()
                    if ($item.aliases -and $item.aliases.Count -gt 0) {
                        $newAliasNames = @($item.aliases | ForEach-Object { $_.name })
                    }
                    
                    # Merge and deduplicate
                    $mergedAliases = @()
                    $seenLower = @{}
                    foreach ($alias in ($existingAliasNames + $newAliasNames)) {
                        $lowerAlias = $alias.ToLower().Trim()
                        if (-not $seenLower.ContainsKey($lowerAlias)) {
                            $seenLower[$lowerAlias] = $true
                            $mergedAliases += $alias
                        }
                    }
                    
                    # Check if anything actually changed
                    if (-not (Test-UnitChanged -Existing $existingUnit -New $item -MergedAliases $mergedAliases)) {
                        Write-Verbose "  $counter Unchanged: $itemName"
                        $stats.Unchanged++
                        continue
                    }
                    
                    # Build change list for WhatIf
                    $changes = @()
                    if ($existingUnit.name -ne $itemName) {
                        $changes += @{ Field = "name"; Old = $existingUnit.name; New = $itemName }
                    }
                    if ($existingUnit.pluralName -ne $item.pluralName -and ![string]::IsNullOrEmpty($item.pluralName)) {
                        $changes += @{ Field = "pluralName"; Old = $existingUnit.pluralName; New = $item.pluralName }
                    }
                    if ($existingUnit.abbreviation -ne $item.abbreviation -and ![string]::IsNullOrEmpty($item.abbreviation)) {
                        $changes += @{ Field = "abbreviation"; Old = $existingUnit.abbreviation; New = $item.abbreviation }
                    }
                    if ($existingUnit.description -ne $item.description -and ![string]::IsNullOrEmpty($item.description)) {
                        $descPreview = if ($item.description.Length -gt 40) { $item.description.Substring(0,40) + "..." } else { $item.description }
                        $changes += @{ Field = "description"; Old = ""; New = $descPreview }
                    }
                    $existingAliasStr = ($existingAliasNames | Sort-Object) -join ", "
                    $mergedAliasStr = ($mergedAliases | Sort-Object) -join ", "
                    if ($existingAliasStr -ne $mergedAliasStr) {
                        $changes += @{ Field = "aliases"; Old = ($existingAliasNames -join ", "); New = ($mergedAliases -join ", ") }
                    }
                    
                    if ($WhatIfPreference) {
                        Write-Host "  $counter " -NoNewline
                        Write-Host "Would UPDATE " -ForegroundColor Yellow -NoNewline
                        Write-Host "(matched by $matchMethod): " -NoNewline
                        Write-Host "$itemName" -ForegroundColor Cyan
                        foreach ($change in $changes) {
                            $oldVal = if ([string]::IsNullOrEmpty($change.Old)) { "(empty)" } else { $change.Old }
                            $newVal = if ([string]::IsNullOrEmpty($change.New)) { "(empty)" } else { $change.New }
                            Write-Host "          $($change.Field.PadRight(12)): " -NoNewline
                            Write-Host "'$oldVal'" -ForegroundColor Red -NoNewline
                            Write-Host " -> " -NoNewline
                            Write-Host "'$newVal'" -ForegroundColor Green
                        }
                        $stats.Updated++
                    }
                    elseif ($PSCmdlet.ShouldProcess($itemName, "Update unit")) {
                        $aliases = @($mergedAliases | ForEach-Object { @{ name = $_ } })
                        
                        $updateData = @{
                            name = $itemName
                        }
                        
                        if (![string]::IsNullOrEmpty($item.pluralName)) {
                            $updateData.pluralName = $item.pluralName
                        }
                        if (![string]::IsNullOrEmpty($item.description)) {
                            $updateData.description = $item.description
                        }
                        if (![string]::IsNullOrEmpty($item.abbreviation)) {
                            $updateData.abbreviation = $item.abbreviation
                        }
                        if (![string]::IsNullOrEmpty($item.pluralAbbreviation)) {
                            $updateData.pluralAbbreviation = $item.pluralAbbreviation
                        }
                        if ($null -ne $item.useAbbreviation) {
                            $updateData.useAbbreviation = [bool]$item.useAbbreviation
                        }
                        if ($null -ne $item.fraction) {
                            $updateData.fraction = [bool]$item.fraction
                        }
                        if ($aliases.Count -gt 0) {
                            $updateData.aliases = $aliases
                        }
                        
                        Update-MealieUnit -Id $existingUnit.id -Data $updateData | Out-Null
                        Write-Host "  $counter Updated (matched by $matchMethod): $itemName" -ForegroundColor Yellow
                        $stats.Updated++
                        
                        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                    }
                }
                else {
                    Write-Verbose "  $counter Skipped (exists, matched by $matchMethod): $itemName"
                    $stats.Skipped++
                }
            }
            else {
                if ($WhatIfPreference) {
                    Write-Host "  $counter " -NoNewline
                    Write-Host "Would CREATE" -ForegroundColor Green -NoNewline
                    Write-Host ": " -NoNewline
                    Write-Host "$itemName" -ForegroundColor Cyan
                    if (![string]::IsNullOrEmpty($item.pluralName)) {
                        Write-Host "          pluralName   : " -NoNewline
                        Write-Host "'$($item.pluralName)'" -ForegroundColor Green
                    }
                    if (![string]::IsNullOrEmpty($item.abbreviation)) {
                        Write-Host "          abbreviation : " -NoNewline
                        Write-Host "'$($item.abbreviation)'" -ForegroundColor Green
                    }
                    if ($item.aliases -and $item.aliases.Count -gt 0) {
                        $aliasStr = ($item.aliases | ForEach-Object { $_.name }) -join ", "
                        Write-Host "          aliases      : " -NoNewline
                        Write-Host "'$aliasStr'" -ForegroundColor Green
                    }
                    $stats.Created++
                }
                elseif ($PSCmdlet.ShouldProcess($itemName, "Create unit")) {
                    $aliasNames = @()
                    if ($item.aliases -and @($item.aliases).Count -gt 0) {
                        $aliasNames = @($item.aliases | ForEach-Object { $_.name })
                    }
                    
                    $params = @{
                        Name = $itemName
                    }
                    if (![string]::IsNullOrEmpty($item.pluralName)) {
                        $params.PluralName = $item.pluralName
                    }
                    if (![string]::IsNullOrEmpty($item.description)) {
                        $params.Description = $item.description
                    }
                    if (![string]::IsNullOrEmpty($item.abbreviation)) {
                        $params.Abbreviation = $item.abbreviation
                    }
                    if (![string]::IsNullOrEmpty($item.pluralAbbreviation)) {
                        $params.PluralAbbreviation = $item.pluralAbbreviation
                    }
                    if ($null -ne $item.useAbbreviation) {
                        $params.UseAbbreviation = [bool]$item.useAbbreviation
                    }
                    if ($null -ne $item.fraction) {
                        $params.Fraction = [bool]$item.fraction
                    }
                    if ($aliasNames.Count -gt 0) {
                        $params.Aliases = $aliasNames
                    }
                    
                    New-MealieUnit @params | Out-Null
                    Write-Host "  $counter Created: $itemName" -ForegroundColor Green
                    $stats.Created++
                    
                    if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                }
            }
        }
        catch {
            Write-Warning "  $counter Error processing '$itemName': $_"
            $stats.Errors++
        }
    }
    
    Write-Progress -Activity "Importing Units" -Completed
    
    Write-Host "`nImport Summary:" -ForegroundColor Cyan
    Write-Host "  Created:   $($stats.Created)"
    Write-Host "  Updated:   $($stats.Updated)"
    Write-Host "  Unchanged: $($stats.Unchanged)"
    Write-Host "  Skipped:   $($stats.Skipped)"
    Write-Host "  Errors:    $($stats.Errors)"
    if ($stats.Conflicts -gt 0) {
        Write-Host "  Conflicts: $($stats.Conflicts)" -ForegroundColor Red
    }
    
    return $stats
}

#region Organizers Functions (Categories, Tags, Tools)

function Get-MealieCategories {
    <#
    .SYNOPSIS
        Get all categories from Mealie
    #>
    [CmdletBinding()]
    param(
        [switch]$All
    )
    
    $items = @()
    $page = 1
    $perPage = 100
    
    do {
        $response = Invoke-MealieRequest -Endpoint "/api/organizers/categories?page=$page`&perPage=$perPage" -Method 'GET'
        $items += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $items
}

function New-MealieCategory {
    <#
    .SYNOPSIS
        Create a new category in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    $body = @{
        name = $Name
    }
    
    return Invoke-MealieRequest -Endpoint '/api/organizers/categories' -Method 'POST' -Body $body
}

function Update-MealieCategory {
    <#
    .SYNOPSIS
        Update an existing category in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [hashtable]$Data
    )
    
    $body = @{
        id = $Id
    }
    
    foreach ($key in $Data.Keys) {
        if ($null -ne $Data[$key]) {
            $body[$key] = $Data[$key]
        }
    }
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/categories/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieCategory {
    <#
    .SYNOPSIS
        Delete a category from Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/categories/$Id" -Method 'DELETE'
}

function Get-MealieTags {
    <#
    .SYNOPSIS
        Get all tags from Mealie
    #>
    [CmdletBinding()]
    param(
        [switch]$All
    )
    
    $items = @()
    $page = 1
    $perPage = 100
    
    do {
        $response = Invoke-MealieRequest -Endpoint "/api/organizers/tags?page=$page`&perPage=$perPage" -Method 'GET'
        $items += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $items
}

function New-MealieTag {
    <#
    .SYNOPSIS
        Create a new tag in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    $body = @{
        name = $Name
    }
    
    return Invoke-MealieRequest -Endpoint '/api/organizers/tags' -Method 'POST' -Body $body
}

function Update-MealieTag {
    <#
    .SYNOPSIS
        Update an existing tag in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [hashtable]$Data
    )
    
    $body = @{
        id = $Id
    }
    
    foreach ($key in $Data.Keys) {
        if ($null -ne $Data[$key]) {
            $body[$key] = $Data[$key]
        }
    }
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/tags/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieTag {
    <#
    .SYNOPSIS
        Delete a tag from Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/tags/$Id" -Method 'DELETE'
}

function Get-MealieTools {
    <#
    .SYNOPSIS
        Get all tools from Mealie
    #>
    [CmdletBinding()]
    param(
        [switch]$All
    )
    
    $items = @()
    $page = 1
    $perPage = 100
    
    do {
        $response = Invoke-MealieRequest -Endpoint "/api/organizers/tools?page=$page`&perPage=$perPage" -Method 'GET'
        $items += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $items
}

function New-MealieTool {
    <#
    .SYNOPSIS
        Create a new tool in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    $body = @{
        name = $Name
    }
    
    return Invoke-MealieRequest -Endpoint '/api/organizers/tools' -Method 'POST' -Body $body
}

function Update-MealieTool {
    <#
    .SYNOPSIS
        Update an existing tool in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [hashtable]$Data
    )
    
    $body = @{
        id = $Id
    }
    
    foreach ($key in $Data.Keys) {
        if ($null -ne $Data[$key]) {
            $body[$key] = $Data[$key]
        }
    }
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/tools/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieTool {
    <#
    .SYNOPSIS
        Delete a tool from Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/organizers/tools/$Id" -Method 'DELETE'
}

#endregion

#region Labels Functions

function Get-MealieLabels {
    <#
    .SYNOPSIS
        Get all labels from Mealie
    #>
    [CmdletBinding()]
    param(
        [switch]$All
    )
    
    $items = @()
    $page = 1
    $perPage = 100
    
    do {
        $response = Invoke-MealieRequest -Endpoint "/api/groups/labels?page=$page`&perPage=$perPage" -Method 'GET'
        $items += $response.items
        $page++
    } while ($All -and $response.items.Count -eq $perPage)
    
    return $items
}

function New-MealieLabel {
    <#
    .SYNOPSIS
        Create a new label in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$Color = "#1976D2"
    )
    
    $body = @{
        name  = $Name
        color = $Color
    }
    
    return Invoke-MealieRequest -Endpoint '/api/groups/labels' -Method 'POST' -Body $body
}

function Update-MealieLabel {
    <#
    .SYNOPSIS
        Update an existing label in Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [hashtable]$Data
    )
    
    $body = @{
        id = $Id
    }
    
    foreach ($key in $Data.Keys) {
        if ($null -ne $Data[$key]) {
            $body[$key] = $Data[$key]
        }
    }
    
    return Invoke-MealieRequest -Endpoint "/api/groups/labels/$Id" -Method 'PUT' -Body $body
}

function Remove-MealieLabel {
    <#
    .SYNOPSIS
        Delete a label from Mealie
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )
    
    return Invoke-MealieRequest -Endpoint "/api/groups/labels/$Id" -Method 'DELETE'
}

function Import-MealieLabels {
    <#
    .SYNOPSIS
        Import labels from a JSON file
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER UpdateExisting
        Update labels that already exist (matched by name)
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$UpdateExisting,
        
        [int]$ThrottleMs = 100
    )
    
    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }
    
    $importData = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $existingItems = Get-MealieLabels -All
    
    # Create lookup by name
    $existingByName = @{}
    foreach ($item in $existingItems) {
        $existingByName[$item.name.ToLower().Trim()] = $item
    }
    
    $stats = @{
        Created   = 0
        Updated   = 0
        Unchanged = 0
        Skipped   = 0
        Errors    = 0
    }
    
    $total = @($importData).Count
    $padWidth = $total.ToString().Length
    $current = 0
    
    foreach ($item in $importData) {
        $current++
        $counter = "[$($current.ToString().PadLeft($padWidth))/$total]"
        $itemName = $item.name.Trim()
        $existingItem = $existingByName[$itemName.ToLower()]
        
        Write-Progress -Activity "Importing Labels" -Status "$current of $total - $itemName" -PercentComplete ([math]::Round(($current / $total) * 100))
        
        try {
            if ($existingItem) {
                if ($UpdateExisting) {
                    # Check if anything actually changed
                    if (-not (Test-LabelChanged -Existing $existingItem -New $item)) {
                        Write-Verbose "  $counter Unchanged: $itemName"
                        $stats.Unchanged++
                        continue
                    }
                    
                    if ($PSCmdlet.ShouldProcess($itemName, "Update Label")) {
                        $updateData = @{
                            name    = $itemName
                            groupId = $existingItem.groupId  # Required by API
                        }
                        if (![string]::IsNullOrEmpty($item.color)) {
                            $updateData.color = $item.color
                        }
                        
                        Update-MealieLabel -Id $existingItem.id -Data $updateData | Out-Null
                        Write-Host "  $counter Updated: $itemName" -ForegroundColor Yellow
                        $stats.Updated++
                        
                        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                    }
                }
                else {
                    Write-Verbose "  $counter Skipped (exists): $itemName"
                    $stats.Skipped++
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess($itemName, "Create Label")) {
                    $color = if (![string]::IsNullOrEmpty($item.color)) { $item.color } else { "#1976D2" }
                    New-MealieLabel -Name $itemName -Color $color | Out-Null
                    Write-Host "  $counter Created: $itemName" -ForegroundColor Green
                    $stats.Created++
                    
                    if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                }
            }
        }
        catch {
            Write-Warning "  $counter Error processing '$itemName': $_"
            $stats.Errors++
        }
    }
    
    Write-Progress -Activity "Importing Labels" -Completed
    
    Write-Host "`nImport Summary:" -ForegroundColor Cyan
    Write-Host "  Created:   $($stats.Created)"
    Write-Host "  Updated:   $($stats.Updated)"
    Write-Host "  Unchanged: $($stats.Unchanged)"
    Write-Host "  Skipped:   $($stats.Skipped)"
    Write-Host "  Errors:    $($stats.Errors)"
    
    return $stats
}

function Export-MealieLabels {
    <#
    .SYNOPSIS
        Export all labels to a JSON file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $items = Get-MealieLabels -All
    $items | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
    Write-Host "Exported $($items.Count) labels to: $Path" -ForegroundColor Green
}

#endregion

#region Import/Export Organizers

function Import-MealieOrganizers {
    <#
    .SYNOPSIS
        Import categories, tags, or tools from a JSON file
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER Type
        Type of organizer: Categories, Tags, or Tools
    .PARAMETER UpdateExisting
        Update items that already exist (matched by name)
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [ValidateSet('Categories', 'Tags', 'Tools')]
        [string]$Type,
        
        [switch]$UpdateExisting,
        
        [int]$ThrottleMs = 100
    )
    
    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }
    
    $importData = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    
    # Get existing items based on type
    $existingItems = switch ($Type) {
        'Categories' { Get-MealieCategories -All }
        'Tags' { Get-MealieTags -All }
        'Tools' { Get-MealieTools -All }
    }
    
    # Create lookup by name
    $existingByName = @{}
    foreach ($item in $existingItems) {
        $existingByName[$item.name.ToLower().Trim()] = $item
    }
    
    $stats = @{
        Created   = 0
        Updated   = 0
        Unchanged = 0
        Skipped   = 0
        Errors    = 0
    }
    
    $total = @($importData).Count
    $padWidth = $total.ToString().Length
    $current = 0
    
    foreach ($item in $importData) {
        $current++
        $counter = "[$($current.ToString().PadLeft($padWidth))/$total]"
        $itemName = $item.name.Trim()
        $existingItem = $existingByName[$itemName.ToLower()]
        
        Write-Progress -Activity "Importing $Type" -Status "$current of $total - $itemName" -PercentComplete ([math]::Round(($current / $total) * 100))
        
        try {
            if ($existingItem) {
                if ($UpdateExisting) {
                    # Check if anything actually changed
                    if (-not (Test-OrganizerChanged -Existing $existingItem -New $item)) {
                        Write-Verbose "  $counter Unchanged: $itemName"
                        $stats.Unchanged++
                        continue
                    }
                    
                    if ($PSCmdlet.ShouldProcess($itemName, "Update $Type")) {
                        $updateData = @{
                            name    = $itemName
                            groupId = $existingItem.groupId  # Required by API
                        }
                        
                        switch ($Type) {
                            'Categories' { Update-MealieCategory -Id $existingItem.id -Data $updateData | Out-Null }
                            'Tags' { Update-MealieTag -Id $existingItem.id -Data $updateData | Out-Null }
                            'Tools' { Update-MealieTool -Id $existingItem.id -Data $updateData | Out-Null }
                        }
                        
                        Write-Host "  $counter Updated: $itemName" -ForegroundColor Yellow
                        $stats.Updated++
                        
                        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                    }
                }
                else {
                    Write-Verbose "  $counter Skipped (exists): $itemName"
                    $stats.Skipped++
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess($itemName, "Create $Type")) {
                    switch ($Type) {
                        'Categories' { New-MealieCategory -Name $itemName | Out-Null }
                        'Tags' { New-MealieTag -Name $itemName | Out-Null }
                        'Tools' { New-MealieTool -Name $itemName | Out-Null }
                    }
                    
                    Write-Host "  $counter Created: $itemName" -ForegroundColor Green
                    $stats.Created++
                    
                    if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                }
            }
        }
        catch {
            Write-Warning "  $counter Error processing '$itemName': $_"
            $stats.Errors++
        }
    }
    
    Write-Progress -Activity "Importing $Type" -Completed
    
    Write-Host "`nImport Summary:" -ForegroundColor Cyan
    Write-Host "  Created:   $($stats.Created)"
    Write-Host "  Updated:   $($stats.Updated)"
    Write-Host "  Unchanged: $($stats.Unchanged)"
    Write-Host "  Skipped:   $($stats.Skipped)"
    Write-Host "  Errors:    $($stats.Errors)"
    
    return $stats
}

function Export-MealieCategories {
    <#
    .SYNOPSIS
        Export all categories to a JSON file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $items = Get-MealieCategories -All
    $items | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
    Write-Host "Exported $($items.Count) categories to: $Path" -ForegroundColor Green
}

function Export-MealieTags {
    <#
    .SYNOPSIS
        Export all tags to a JSON file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $items = Get-MealieTags -All
    $items | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
    Write-Host "Exported $($items.Count) tags to: $Path" -ForegroundColor Green
}

function Export-MealieTools {
    <#
    .SYNOPSIS
        Export all tools to a JSON file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $items = Get-MealieTools -All
    $items | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
    Write-Host "Exported $($items.Count) tools to: $Path" -ForegroundColor Green
}

#endregion

#region Export Foods/Units

function Export-MealieFoods {
    <#
    .SYNOPSIS
        Export foods to JSON file(s)
    .PARAMETER Path
        Path to the JSON file (or folder when using -SplitByLabel)
    .PARAMETER Label
        Export only foods with this label name
    .PARAMETER SplitByLabel
        Export to separate files per label. Path should be a folder.
    .NOTES
        Adds 'label' field (label name) for roundtrip compatibility with Import-MealieFoods
    .EXAMPLE
        Export-MealieFoods -Path .\Foods.json
        # Exports all foods to single file
    .EXAMPLE
        Export-MealieFoods -Path .\Foods.json -Label "Groente"
        # Exports only foods with label "Groente"
    .EXAMPLE
        Export-MealieFoods -Path .\FoodsExport -SplitByLabel
        # Exports to FoodsExport\Groente.json, FoodsExport\Vlees.json, etc.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Label,
        
        [switch]$SplitByLabel
    )
    
    $foods = Get-MealieFoods -All
    
    # Helper function to transform food for export
    $transformFood = {
        param($food)
        $result = [ordered]@{
            id          = $food.id
            name        = $food.name
            pluralName  = $food.pluralName
            description = $food.description
        }
        
        if ($food.label -and $food.label.name) {
            $result.label = $food.label.name
        }
        
        if ($food.aliases -and $food.aliases.Count -gt 0) {
            $result.aliases = @($food.aliases | ForEach-Object { @{ name = $_.name } })
        }
        else {
            $result.aliases = @()
        }
        
        [PSCustomObject]$result
    }
    
    # Helper to ensure parent directory exists
    $ensureParentDir = {
        param($filePath)
        $parentDir = Split-Path -Parent $filePath
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
    }
    
    if ($SplitByLabel) {
        # Create output folder if needed
        if (-not (Test-Path $Path)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
        
        # Group foods by label
        $grouped = $foods | Group-Object { if ($_.label) { $_.label.name } else { "_Geen_Label" } }
        
        $totalExported = 0
        foreach ($group in $grouped) {
            # Sanitize filename (remove invalid characters)
            $safeName = $group.Name -replace '[\\/:*?"<>|]', '_'
            $filePath = Join-Path $Path "$safeName.json"
            
            $exportData = $group.Group | ForEach-Object { & $transformFood $_ }
            $exportData | ConvertTo-Json -Depth 10 | Set-Content $filePath -Encoding UTF8
            
            Write-Host "  Exported $($group.Count) foods to: $filePath" -ForegroundColor Green
            $totalExported += $group.Count
        }
        
        Write-Host "`nTotal: $totalExported foods exported to $($grouped.Count) files in: $Path" -ForegroundColor Cyan
    }
    elseif ($Label) {
        # Filter by specific label
        $filtered = $foods | Where-Object { $_.label -and $_.label.name -eq $Label }
        
        if ($filtered.Count -eq 0) {
            Write-Warning "No foods found with label: $Label"
            return
        }
        
        & $ensureParentDir $Path
        $exportData = $filtered | ForEach-Object { & $transformFood $_ }
        $exportData | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
        Write-Host "Exported $($filtered.Count) foods with label '$Label' to: $Path" -ForegroundColor Green
    }
    else {
        # Export all to single file
        & $ensureParentDir $Path
        $exportData = $foods | ForEach-Object { & $transformFood $_ }
        $exportData | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
        Write-Host "Exported $($foods.Count) foods to: $Path" -ForegroundColor Green
    }
}

function Export-MealieUnits {
    <#
    .SYNOPSIS
        Export all units to a JSON file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $units = Get-MealieUnits -All
    
    # Ensure parent directory exists
    $parentDir = Split-Path -Parent $Path
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    
    # Transform for cleaner export (include id for matching)
    $exportData = $units | ForEach-Object {
        $result = [ordered]@{
            id                  = $_.id
            name                = $_.name
            pluralName          = $_.pluralName
            description         = $_.description
            abbreviation        = $_.abbreviation
            pluralAbbreviation  = $_.pluralAbbreviation
            useAbbreviation     = $_.useAbbreviation
            fraction            = $_.fraction
        }
        
        if ($_.aliases -and $_.aliases.Count -gt 0) {
            $result.aliases = @($_.aliases | ForEach-Object { @{ name = $_.name } })
        }
        else {
            $result.aliases = @()
        }
        
        [PSCustomObject]$result
    }
    
    $exportData | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
    Write-Host "Exported $($units.Count) units to: $Path" -ForegroundColor Green
}

#endregion

# Export module members
Export-ModuleMember -Function @(
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
    'Export-MealieCategories'
    # Tags
    'Get-MealieTags'
    'New-MealieTag'
    'Update-MealieTag'
    'Remove-MealieTag'
    'Export-MealieTags'
    # Tools
    'Get-MealieTools'
    'New-MealieTool'
    'Update-MealieTool'
    'Remove-MealieTool'
    'Export-MealieTools'
    # Generic Organizers Import
    'Import-MealieOrganizers'
)