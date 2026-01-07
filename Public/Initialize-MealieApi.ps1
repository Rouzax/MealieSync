#Requires -Version 7.0
<#
.SYNOPSIS
    API initialization function for MealieSync
.DESCRIPTION
    Provides the Initialize-MealieApi function to establish a connection
    to a Mealie instance and validate authentication.
.NOTES
    This is a public function - exported by the module.
#>

function Initialize-MealieApi {
    <#
    .SYNOPSIS
        Initialize the Mealie API connection
    .DESCRIPTION
        Establishes a connection to a Mealie instance by storing the base URL
        and API token. Tests the connection by fetching the current user.
        Optionally caches household information for validation in import operations.
    .PARAMETER BaseUrl
        The base URL of your Mealie instance (e.g., http://localhost:9000)
    .PARAMETER Token
        Your Mealie API token (from /user/profile/api-tokens in Mealie)
    .PARAMETER CacheHouseholds
        Pre-cache household information for validation during imports
    .OUTPUTS
        [bool] True if connection successful, False otherwise
    .EXAMPLE
        Initialize-MealieApi -BaseUrl "http://mealie.local:9000" -Token "your-api-token"
    .EXAMPLE
        # With household caching for import validation
        Initialize-MealieApi -BaseUrl $env:MEALIE_URL -Token $env:MEALIE_TOKEN -CacheHouseholds
    .EXAMPLE
        # Using config file
        $config = Get-Content .\mealie-config.json | ConvertFrom-Json
        Initialize-MealieApi -BaseUrl $config.BaseUrl -Token $config.Token
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Token,
        
        [switch]$CacheHouseholds
    )
    
    # Normalize URL (remove trailing slash)
    $script:MealieConfig.BaseUrl = $BaseUrl.TrimEnd('/')
    $script:MealieConfig.Token = $Token
    $script:MealieConfig.Headers = @{
        'Authorization' = "Bearer $Token"
        'Content-Type'  = 'application/json; charset=utf-8'
        'Accept'        = 'application/json'
    }
    
    # Clear any cached data from previous connection
    $script:HouseholdCache = $null
    
    # Test connection by fetching current user
    try {
        $response = Invoke-MealieRequest -Endpoint '/api/users/self' -Method 'GET'
        Write-Host "OK: Connected to Mealie as: $($response.username)" -ForegroundColor Green
        
        # Optionally cache households
        if ($CacheHouseholds) {
            Write-Verbose "Caching household information..."
            $null = Get-ValidHouseholds -Force
            $count = if ($script:HouseholdCache) { $script:HouseholdCache.Count } else { 0 }
            Write-Verbose "Cached $count households"
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to connect to Mealie: $_"
        
        # Clear config on failure
        $script:MealieConfig.BaseUrl = $null
        $script:MealieConfig.Token = $null
        $script:MealieConfig.Headers = $null
        
        return $false
    }
}
