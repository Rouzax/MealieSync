#Requires -Version 5.1
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
        Write-Host "✓ Connected to Mealie as: $($response.username)" -ForegroundColor Green
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
    
    # Compare aliases
    if (-not (Compare-Aliases $Existing.aliases $New.aliases)) { return $true }
    
    return $false
}

function Test-UnitChanged {
    <#
    .SYNOPSIS
        Check if a unit item has changes compared to existing data
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Existing,
        
        [Parameter(Mandatory)]
        [object]$New
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
    
    # Compare aliases
    if (-not (Compare-Aliases $Existing.aliases $New.aliases)) { return $true }
    
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
        $params.Body = $jsonBody
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
        $response = Invoke-MealieRequest -Endpoint "/api/foods?page=$page&perPage=$perPage" -Method 'GET'
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
        $response = Invoke-MealieRequest -Endpoint "/api/units?page=$page&perPage=$perPage" -Method 'GET'
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
        Update foods that already exist (matched by name or id)
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER WhatIf
        Show what would happen without making changes
    .NOTES
        Supports 'label' field in JSON (label name). The label must already exist in Mealie.
        If a label name is not found, a warning is shown and the food is imported without label.
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
    $existingFoods = Get-MealieFoods -All
    
    # Fetch labels and create lookup by name (case-insensitive)
    $existingLabels = Get-MealieLabels -All
    $labelsByName = @{}
    foreach ($label in $existingLabels) {
        $labelsByName[$label.name.ToLower().Trim()] = $label
    }
    
    # Create food lookup by name (lowercase for case-insensitive matching)
    $existingByName = @{}
    foreach ($food in $existingFoods) {
        $existingByName[$food.name.ToLower().Trim()] = $food
    }
    
    $stats = @{
        Created       = 0
        Updated       = 0
        Unchanged     = 0
        Skipped       = 0
        Errors        = 0
        LabelWarnings = 0
    }
    
    $total = @($importData).Count
    $current = 0
    
    foreach ($item in $importData) {
        $current++
        $itemName = $item.name.Trim()
        $existingFood = $existingByName[$itemName.ToLower()]
        
        # Progress indicator
        $percentComplete = [math]::Round(($current / $total) * 100)
        Write-Progress -Activity "Importing Foods" -Status "$current of $total - $itemName" -PercentComplete $percentComplete
        
        # Resolve label name to labelId
        $resolvedLabelId = $null
        if (![string]::IsNullOrEmpty($item.label)) {
            $labelLookup = $labelsByName[$item.label.ToLower().Trim()]
            if ($labelLookup) {
                $resolvedLabelId = $labelLookup.id
            }
            else {
                Write-Warning "  [$current/$total] Label not found: '$($item.label)' for food '$itemName'"
                $stats.LabelWarnings++
            }
        }
        
        try {
            if ($existingFood) {
                if ($UpdateExisting) {
                    # Check if anything actually changed (including label)
                    if (-not (Test-FoodChanged -Existing $existingFood -New $item -ResolvedLabelId $resolvedLabelId)) {
                        Write-Verbose "  [$current/$total] Unchanged: $itemName"
                        $stats.Unchanged++
                        continue
                    }
                    
                    if ($PSCmdlet.ShouldProcess($itemName, "Update food")) {
                        # Prepare aliases array - only if aliases exist in source
                        $aliases = @()
                        if ($item.aliases -and @($item.aliases).Count -gt 0) {
                            $aliases = @($item.aliases | ForEach-Object { @{ name = $_.name } })
                        }
                        
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
                        Write-Host "  [$current/$total] Updated: $itemName" -ForegroundColor Yellow
                        $stats.Updated++
                        
                        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                    }
                }
                else {
                    Write-Verbose "  [$current/$total] Skipped (exists): $itemName"
                    $stats.Skipped++
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess($itemName, "Create food")) {
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
                    Write-Host "  [$current/$total] Created: $itemName" -ForegroundColor Green
                    $stats.Created++
                    
                    if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                }
            }
        }
        catch {
            Write-Warning "  [$current/$total] Error processing '$itemName': $_"
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
    
    return $stats
}

function Import-MealieUnits {
    <#
    .SYNOPSIS
        Import units from a JSON file, creating new or updating existing
    .PARAMETER Path
        Path to the JSON file containing unit data
    .PARAMETER UpdateExisting
        Update units that already exist (matched by name or id)
    .PARAMETER ThrottleMs
        Milliseconds to wait between API calls (default: 100)
    .PARAMETER WhatIf
        Show what would happen without making changes
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
    $existingUnits = Get-MealieUnits -All
    
    # Create lookup by name
    $existingByName = @{}
    foreach ($unit in $existingUnits) {
        $existingByName[$unit.name.ToLower().Trim()] = $unit
    }
    
    $stats = @{
        Created   = 0
        Updated   = 0
        Unchanged = 0
        Skipped   = 0
        Errors    = 0
    }
    
    $total = @($importData).Count
    $current = 0
    
    foreach ($item in $importData) {
        $current++
        $itemName = $item.name.Trim()
        $existingUnit = $existingByName[$itemName.ToLower()]
        
        # Progress indicator
        $percentComplete = [math]::Round(($current / $total) * 100)
        Write-Progress -Activity "Importing Units" -Status "$current of $total - $itemName" -PercentComplete $percentComplete
        
        try {
            if ($existingUnit) {
                if ($UpdateExisting) {
                    # Check if anything actually changed
                    if (-not (Test-UnitChanged -Existing $existingUnit -New $item)) {
                        Write-Verbose "  [$current/$total] Unchanged: $itemName"
                        $stats.Unchanged++
                        continue
                    }
                    
                    if ($PSCmdlet.ShouldProcess($itemName, "Update unit")) {
                        # Prepare aliases array - only if aliases exist
                        $aliases = @()
                        if ($item.aliases -and @($item.aliases).Count -gt 0) {
                            $aliases = @($item.aliases | ForEach-Object { @{ name = $_.name } })
                        }
                        
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
                        Write-Host "  [$current/$total] Updated: $itemName" -ForegroundColor Yellow
                        $stats.Updated++
                        
                        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                    }
                }
                else {
                    Write-Verbose "  [$current/$total] Skipped (exists): $itemName"
                    $stats.Skipped++
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess($itemName, "Create unit")) {
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
                    Write-Host "  [$current/$total] Created: $itemName" -ForegroundColor Green
                    $stats.Created++
                    
                    if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                }
            }
        }
        catch {
            Write-Warning "  [$current/$total] Error processing '$itemName': $_"
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
        $response = Invoke-MealieRequest -Endpoint "/api/organizers/categories?page=$page&perPage=$perPage" -Method 'GET'
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
        $response = Invoke-MealieRequest -Endpoint "/api/organizers/tags?page=$page&perPage=$perPage" -Method 'GET'
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
        $response = Invoke-MealieRequest -Endpoint "/api/organizers/tools?page=$page&perPage=$perPage" -Method 'GET'
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
        $response = Invoke-MealieRequest -Endpoint "/api/groups/labels?page=$page&perPage=$perPage" -Method 'GET'
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
    $current = 0
    
    foreach ($item in $importData) {
        $current++
        $itemName = $item.name.Trim()
        $existingItem = $existingByName[$itemName.ToLower()]
        
        Write-Progress -Activity "Importing Labels" -Status "$current of $total - $itemName" -PercentComplete ([math]::Round(($current / $total) * 100))
        
        try {
            if ($existingItem) {
                if ($UpdateExisting) {
                    # Check if anything actually changed
                    if (-not (Test-LabelChanged -Existing $existingItem -New $item)) {
                        Write-Verbose "  [$current/$total] Unchanged: $itemName"
                        $stats.Unchanged++
                        continue
                    }
                    
                    if ($PSCmdlet.ShouldProcess($itemName, "Update Label")) {
                        $updateData = @{ name = $itemName }
                        if (![string]::IsNullOrEmpty($item.color)) {
                            $updateData.color = $item.color
                        }
                        
                        Update-MealieLabel -Id $existingItem.id -Data $updateData | Out-Null
                        Write-Host "  [$current/$total] Updated: $itemName" -ForegroundColor Yellow
                        $stats.Updated++
                        
                        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                    }
                }
                else {
                    Write-Verbose "  [$current/$total] Skipped (exists): $itemName"
                    $stats.Skipped++
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess($itemName, "Create Label")) {
                    $color = if (![string]::IsNullOrEmpty($item.color)) { $item.color } else { "#1976D2" }
                    New-MealieLabel -Name $itemName -Color $color | Out-Null
                    Write-Host "  [$current/$total] Created: $itemName" -ForegroundColor Green
                    $stats.Created++
                    
                    if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                }
            }
        }
        catch {
            Write-Warning "  [$current/$total] Error processing '$itemName': $_"
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
    $current = 0
    
    foreach ($item in $importData) {
        $current++
        $itemName = $item.name.Trim()
        $existingItem = $existingByName[$itemName.ToLower()]
        
        Write-Progress -Activity "Importing $Type" -Status "$current of $total - $itemName" -PercentComplete ([math]::Round(($current / $total) * 100))
        
        try {
            if ($existingItem) {
                if ($UpdateExisting) {
                    # Check if anything actually changed
                    if (-not (Test-OrganizerChanged -Existing $existingItem -New $item)) {
                        Write-Verbose "  [$current/$total] Unchanged: $itemName"
                        $stats.Unchanged++
                        continue
                    }
                    
                    if ($PSCmdlet.ShouldProcess($itemName, "Update $Type")) {
                        $updateData = @{ name = $itemName }
                        
                        switch ($Type) {
                            'Categories' { Update-MealieCategory -Id $existingItem.id -Data $updateData | Out-Null }
                            'Tags' { Update-MealieTag -Id $existingItem.id -Data $updateData | Out-Null }
                            'Tools' { Update-MealieTool -Id $existingItem.id -Data $updateData | Out-Null }
                        }
                        
                        Write-Host "  [$current/$total] Updated: $itemName" -ForegroundColor Yellow
                        $stats.Updated++
                        
                        if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                    }
                }
                else {
                    Write-Verbose "  [$current/$total] Skipped (exists): $itemName"
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
                    
                    Write-Host "  [$current/$total] Created: $itemName" -ForegroundColor Green
                    $stats.Created++
                    
                    if ($ThrottleMs -gt 0) { Start-Sleep -Milliseconds $ThrottleMs }
                }
            }
        }
        catch {
            Write-Warning "  [$current/$total] Error processing '$itemName': $_"
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
        
        $exportData = $filtered | ForEach-Object { & $transformFood $_ }
        $exportData | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
        Write-Host "Exported $($filtered.Count) foods with label '$Label' to: $Path" -ForegroundColor Green
    }
    else {
        # Export all to single file
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
    $units | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
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