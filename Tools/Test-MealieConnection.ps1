#Requires -Version 7.0
<#
.SYNOPSIS
    Test connection to Mealie API
.DESCRIPTION
    Verifies connectivity to a Mealie instance by:
    1. Testing network connectivity to the base URL
    2. Authenticating with the API token
    3. Fetching user information
    4. Optionally testing read access to various endpoints

    This is a standalone utility script that uses the MealieApi module.
.PARAMETER ConfigPath
    Path to mealie-config.json file. Defaults to mealie-config.json in the
    MealieSync folder.
.PARAMETER BaseUrl
    Mealie base URL (alternative to config file)
.PARAMETER Token
    Mealie API token (alternative to config file)
.PARAMETER Detailed
    Run additional endpoint tests to verify full API access
.EXAMPLE
    .\Tools\Test-MealieConnection.ps1
    # Uses default config file
.EXAMPLE
    .\Tools\Test-MealieConnection.ps1 -ConfigPath "C:\configs\mealie.json"
    # Uses custom config file
.EXAMPLE
    .\Tools\Test-MealieConnection.ps1 -BaseUrl "http://mealie:9000" -Token "mytoken"
    # Uses direct parameters instead of config file
.EXAMPLE
    .\Tools\Test-MealieConnection.ps1 -Detailed
    # Run full endpoint tests
.NOTES
    Author: MealieSync Project
    Version: 2.0.0
#>
[CmdletBinding(DefaultParameterSetName = 'ConfigFile')]
param(
    [Parameter(ParameterSetName = 'ConfigFile')]
    [string]$ConfigPath,
    
    [Parameter(ParameterSetName = 'Direct', Mandatory)]
    [string]$BaseUrl,
    
    [Parameter(ParameterSetName = 'Direct', Mandatory)]
    [string]$Token,
    
    [switch]$Detailed
)

# Determine script location and module path
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent $scriptRoot
$modulePath = Join-Path $moduleRoot "MealieApi.psd1"

# Helper function for test results
function Write-TestResult {
    param(
        [string]$Test,
        [bool]$Success,
        [string]$Message = ""
    )
    
    $icon = if ($Success) { "✓" } else { "✗" }
    $color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "  [$icon] " -ForegroundColor $color -NoNewline
    Write-Host $Test -NoNewline
    if ($Message) {
        Write-Host " - $Message" -ForegroundColor Gray
    }
    else {
        Write-Host ""
    }
}

Write-Host ""
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host "     MEALIE CONNECTION TEST" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# ============================================================================
# Step 1: Module Check
# ============================================================================
Write-Host "Module Check" -ForegroundColor White
Write-Host ("-" * 30) -ForegroundColor Gray

if (Test-Path $modulePath) {
    Write-TestResult -Test "Module found" -Success $true -Message $modulePath
    
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
        Write-TestResult -Test "Module loaded" -Success $true
    }
    catch {
        Write-TestResult -Test "Module loaded" -Success $false -Message $_.Exception.Message
        $allPassed = $false
        exit 1
    }
}
else {
    Write-TestResult -Test "Module found" -Success $false -Message "Not found at $modulePath"
    exit 1
}

Write-Host ""

# ============================================================================
# Step 2: Configuration
# ============================================================================
Write-Host "Configuration" -ForegroundColor White
Write-Host ("-" * 30) -ForegroundColor Gray

if ($PSCmdlet.ParameterSetName -eq 'ConfigFile') {
    # Find config file
    if ([string]::IsNullOrEmpty($ConfigPath)) {
        $ConfigPath = Join-Path $moduleRoot "mealie-config.json"
    }
    
    if (Test-Path $ConfigPath) {
        Write-TestResult -Test "Config file found" -Success $true -Message $ConfigPath
        
        try {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $BaseUrl = $config.BaseUrl
            $Token = $config.Token
            
            if ([string]::IsNullOrEmpty($BaseUrl) -or [string]::IsNullOrEmpty($Token)) {
                Write-TestResult -Test "Config valid" -Success $false -Message "Missing BaseUrl or Token"
                $allPassed = $false
                exit 1
            }
            
            Write-TestResult -Test "Config parsed" -Success $true
        }
        catch {
            Write-TestResult -Test "Config parsed" -Success $false -Message $_.Exception.Message
            $allPassed = $false
            exit 1
        }
    }
    else {
        Write-TestResult -Test "Config file found" -Success $false -Message "Not found: $ConfigPath"
        Write-Host "`n  Create a config file based on mealie-config-sample.json" -ForegroundColor Yellow
        Write-Host "  Or use -BaseUrl and -Token parameters directly`n" -ForegroundColor Yellow
        exit 1
    }
}
else {
    Write-TestResult -Test "Using direct parameters" -Success $true
}

# Mask token for display
$maskedToken = if ($Token.Length -gt 8) {
    $Token.Substring(0, 4) + "****" + $Token.Substring($Token.Length - 4)
}
else {
    "****"
}

Write-Host ""
Write-Host "  Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host "  Token:    $maskedToken" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# Step 3: Network Connectivity
# ============================================================================
Write-Host "Network Connectivity" -ForegroundColor White
Write-Host ("-" * 30) -ForegroundColor Gray

# Parse URL to get host
try {
    $uri = [System.Uri]::new($BaseUrl)
    $hostName = $uri.Host
    $port = if ($uri.Port -gt 0) { $uri.Port } else { if ($uri.Scheme -eq 'https') { 443 } else { 80 } }
    
    Write-TestResult -Test "URL parsed" -Success $true -Message "$($uri.Scheme)://$hostName`:$port"
}
catch {
    Write-TestResult -Test "URL parsed" -Success $false -Message $_.Exception.Message
    $allPassed = $false
    exit 1
}

# Test TCP connection
try {
    $tcpClient = [System.Net.Sockets.TcpClient]::new()
    $connectTask = $tcpClient.ConnectAsync($hostName, $port)
    $completed = $connectTask.Wait(5000)  # 5 second timeout
    
    if ($completed -and $tcpClient.Connected) {
        Write-TestResult -Test "TCP connection" -Success $true -Message "Port $port reachable"
        $tcpClient.Close()
    }
    else {
        Write-TestResult -Test "TCP connection" -Success $false -Message "Connection timeout"
        $allPassed = $false
    }
}
catch {
    Write-TestResult -Test "TCP connection" -Success $false -Message $_.Exception.InnerException.Message
    $allPassed = $false
}

Write-Host ""

# ============================================================================
# Step 4: API Authentication
# ============================================================================
Write-Host "API Authentication" -ForegroundColor White
Write-Host ("-" * 30) -ForegroundColor Gray

try {
    $connected = Initialize-MealieApi -BaseUrl $BaseUrl -Token $Token -ErrorAction Stop
    
    if ($connected) {
        Write-TestResult -Test "Authentication" -Success $true -Message "Token accepted"
    }
    else {
        Write-TestResult -Test "Authentication" -Success $false -Message "Connection failed"
        $allPassed = $false
    }
}
catch {
    $errorMsg = $_.Exception.Message
    if ($errorMsg -match '401|Unauthorized') {
        Write-TestResult -Test "Authentication" -Success $false -Message "Invalid token (401 Unauthorized)"
    }
    elseif ($errorMsg -match '403|Forbidden') {
        Write-TestResult -Test "Authentication" -Success $false -Message "Access denied (403 Forbidden)"
    }
    else {
        Write-TestResult -Test "Authentication" -Success $false -Message $errorMsg
    }
    $allPassed = $false
}

Write-Host ""

# ============================================================================
# Step 5: Detailed Endpoint Tests (Optional)
# ============================================================================
if ($Detailed -and $allPassed) {
    Write-Host "Endpoint Access Tests" -ForegroundColor White
    Write-Host ("-" * 30) -ForegroundColor Gray
    
    $endpoints = @(
        @{ Name = "Foods"; Func = { Get-MealieFoods } },
        @{ Name = "Units"; Func = { Get-MealieUnits } },
        @{ Name = "Labels"; Func = { Get-MealieLabels } },
        @{ Name = "Categories"; Func = { Get-MealieCategories } },
        @{ Name = "Tags"; Func = { Get-MealieTags } },
        @{ Name = "Tools"; Func = { Get-MealieTools } },
        @{ Name = "Households"; Func = { Get-MealieHouseholds } }
    )
    
    foreach ($endpoint in $endpoints) {
        try {
            $result = & $endpoint.Func
            $count = if ($result -is [array]) { $result.Count } elseif ($null -eq $result) { 0 } else { 1 }
            Write-TestResult -Test $endpoint.Name -Success $true -Message "$count items"
        }
        catch {
            Write-TestResult -Test $endpoint.Name -Success $false -Message $_.Exception.Message
            $allPassed = $false
        }
    }
    
    Write-Host ""
}

# ============================================================================
# Summary
# ============================================================================
Write-Host ("=" * 50) -ForegroundColor Cyan

if ($allPassed) {
    Write-Host ""
    Write-Host "  All tests passed! Connection is working." -ForegroundColor Green
    Write-Host ""
    
    if (-not $Detailed) {
        Write-Host "  Tip: Use -Detailed for comprehensive endpoint tests" -ForegroundColor Gray
        Write-Host ""
    }
    
    exit 0
}
else {
    Write-Host ""
    Write-Host "  Some tests failed. Check the errors above." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Common issues:" -ForegroundColor Yellow
    Write-Host "    - Wrong BaseUrl (check port number)" -ForegroundColor Gray
    Write-Host "    - Invalid or expired API token" -ForegroundColor Gray
    Write-Host "    - Mealie server not running" -ForegroundColor Gray
    Write-Host "    - Firewall blocking connection" -ForegroundColor Gray
    Write-Host ""
    
    exit 1
}
