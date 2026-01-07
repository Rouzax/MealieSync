#Requires -Version 7.0
<#
.SYNOPSIS
    Core API request function for Mealie REST API
.DESCRIPTION
    Internal helper function that handles all HTTP communication with the Mealie API.
    Provides consistent error handling, UTF-8 encoding, and response parsing.
.NOTES
    This is a private function - not exported by the module.
#>

function Invoke-MealieRequest {
    <#
    .SYNOPSIS
        Make an authenticated request to the Mealie API
    .DESCRIPTION
        Handles authentication, JSON encoding/decoding, and error parsing for all API calls.
        Uses UTF-8 encoding for request bodies to properly handle special characters.
    .PARAMETER Endpoint
        The API endpoint path (e.g., '/api/foods')
    .PARAMETER Method
        HTTP method (GET, POST, PUT, DELETE)
    .PARAMETER Body
        Request body object (will be converted to JSON)
    .EXAMPLE
        Invoke-MealieRequest -Endpoint '/api/foods' -Method 'GET'
    .EXAMPLE
        Invoke-MealieRequest -Endpoint '/api/foods' -Method 'POST' -Body @{ name = 'tomaat' }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,
        
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string]$Method = 'GET',
        
        [object]$Body = $null
    )
    
    # Validate API is initialized
    if (-not $script:MealieConfig.BaseUrl) {
        throw "Mealie API not initialized. Call Initialize-MealieApi first."
    }
    
    # Build request parameters
    $uri = "$($script:MealieConfig.BaseUrl)$Endpoint"
    $params = @{
        Uri         = $uri
        Method      = $Method
        Headers     = $script:MealieConfig.Headers
        ErrorAction = 'Stop'
    }
    
    # Add body for POST/PUT requests with UTF-8 encoding
    if ($Body -and $Method -in @('POST', 'PUT')) {
        $jsonBody = $Body | ConvertTo-Json -Depth 10 -Compress
        # Ensure UTF-8 encoding for proper handling of special characters (ë, ü, ñ, etc.)
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
    }
    
    try {
        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        # Extract HTTP status code if available
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        
        # Try to parse API error message
        $errorMessage = $_.ErrorDetails.Message
        if ($errorMessage) {
            $detailMsg = $errorMessage
            try {
                $errorObj = $errorMessage | ConvertFrom-Json -ErrorAction Stop
                # Mealie returns errors in various formats
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
        
        # Re-throw original exception if no custom error message
        throw $_
    }
}
