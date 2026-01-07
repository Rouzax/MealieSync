#Requires -Version 7.0
<#
.SYNOPSIS
    Create a full backup of all Mealie data
.DESCRIPTION
    Exports all data types from Mealie to a timestamped backup folder:
    - Foods.json
    - Units.json
    - Labels.json
    - Categories.json
    - Tags.json
    - Tools.json

    Backup folders are named: Backup_YYYYMMDD_HHMMSS

    This is a standalone utility script that uses the MealieApi module.
.PARAMETER ConfigPath
    Path to mealie-config.json file. Defaults to mealie-config.json in the
    MealieSync folder.
.PARAMETER OutputPath
    Base folder for backups. Defaults to Exports/ in the MealieSync folder.
    A timestamped subfolder will be created.
.PARAMETER Types
    Specific types to backup. Defaults to all types.
    Valid values: Foods, Units, Labels, Categories, Tags, Tools
.PARAMETER NoTimestamp
    Create backup directly in OutputPath without timestamped subfolder.
    Warning: May overwrite existing files.
.EXAMPLE
    .\Tools\Backup-MealieData.ps1
    # Creates backup in Exports/Backup_20260106_143022/
.EXAMPLE
    .\Tools\Backup-MealieData.ps1 -OutputPath "D:\Backups\Mealie"
    # Creates backup in D:\Backups\Mealie\Backup_20260106_143022/
.EXAMPLE
    .\Tools\Backup-MealieData.ps1 -Types Foods,Labels
    # Backup only Foods and Labels
.EXAMPLE
    .\Tools\Backup-MealieData.ps1 -OutputPath ".\CurrentState" -NoTimestamp
    # Creates backup directly in .\CurrentState\ (no timestamp folder)
.NOTES
    Author: MealieSync Project
    Version: 2.0.0
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath,
    
    [string]$OutputPath,
    
    [ValidateSet('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools')]
    [string[]]$Types = @('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools'),
    
    [switch]$NoTimestamp
)

# Determine script location and module path
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent $scriptRoot
$modulePath = Join-Path $moduleRoot "MealieApi.psd1"

# Import the MealieApi module
if (-not (Test-Path $modulePath)) {
    Write-Error "Module not found at: $modulePath"
    exit 1
}

Import-Module $modulePath -Force

# Find config file
if ([string]::IsNullOrEmpty($ConfigPath)) {
    $ConfigPath = Join-Path $moduleRoot "mealie-config.json"
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    Write-Host "`nCreate a config file based on mealie-config-sample.json" -ForegroundColor Yellow
    exit 1
}

# Set default output path
if ([string]::IsNullOrEmpty($OutputPath)) {
    $OutputPath = Join-Path $moduleRoot "Exports"
}

# Create timestamped folder name
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
if ($NoTimestamp) {
    $backupFolder = $OutputPath
}
else {
    $backupFolder = Join-Path $OutputPath "Backup_$timestamp"
}

# Load config and initialize API
try {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    
    Write-Host ""
    Write-Host ("=" * 50) -ForegroundColor Cyan
    Write-Host "        MEALIE BACKUP" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Connecting to Mealie..." -ForegroundColor Gray
    
    $connected = Initialize-MealieApi -BaseUrl $config.BaseUrl -Token $config.Token
    
    if (-not $connected) {
        Write-Error "Failed to connect to Mealie"
        exit 1
    }
}
catch {
    Write-Error "Failed to load config or connect: $_"
    exit 1
}

Write-Host ""

# Create backup folder
if ($PSCmdlet.ShouldProcess($backupFolder, "Create backup folder")) {
    if (-not (Test-Path $backupFolder)) {
        New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
        Write-Host "Created backup folder: $backupFolder" -ForegroundColor Gray
    }
    else {
        Write-Host "Using existing folder: $backupFolder" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Backup Location:" -ForegroundColor White
Write-Host "  $backupFolder" -ForegroundColor Cyan
Write-Host ""
Write-Host "Types to backup:" -ForegroundColor White
Write-Host "  $($Types -join ', ')" -ForegroundColor Cyan
Write-Host ""
Write-Host ("-" * 50) -ForegroundColor Gray
Write-Host ""

# Export functions mapping
$exportFunctions = @{
    'Foods'      = { param($path) Export-MealieFoods -Path $path }
    'Units'      = { param($path) Export-MealieUnits -Path $path }
    'Labels'     = { param($path) Export-MealieLabels -Path $path }
    'Categories' = { param($path) Export-MealieCategories -Path $path }
    'Tags'       = { param($path) Export-MealieTags -Path $path }
    'Tools'      = { param($path) Export-MealieTools -Path $path }
}

# Track results
$results = @{
    Success = @()
    Failed  = @()
}

# Execute backups
foreach ($type in $Types) {
    $fileName = "$type.json"
    $filePath = Join-Path $backupFolder $fileName
    
    Write-Host "Backing up $type..." -ForegroundColor White -NoNewline
    
    if ($PSCmdlet.ShouldProcess($filePath, "Export $type")) {
        try {
            # Suppress the export function output and capture it
            $null = & $exportFunctions[$type] $filePath
            
            # Verify file was created
            if (Test-Path $filePath) {
                $fileSize = (Get-Item $filePath).Length
                $sizeDisplay = if ($fileSize -gt 1KB) {
                    "{0:N1} KB" -f ($fileSize / 1KB)
                }
                else {
                    "$fileSize bytes"
                }
                
                # Count items in file
                $json = Get-Content $filePath -Raw | ConvertFrom-Json
                $itemCount = if ($json.items) { $json.items.Count } else { 0 }
                
                Write-Host " OK" -ForegroundColor Green -NoNewline
                Write-Host " ($itemCount items, $sizeDisplay)" -ForegroundColor Gray
                
                $results.Success += @{
                    Type      = $type
                    Path      = $filePath
                    Items     = $itemCount
                    Size      = $fileSize
                }
            }
            else {
                Write-Host " FAILED" -ForegroundColor Red -NoNewline
                Write-Host " (file not created)" -ForegroundColor Gray
                $results.Failed += $type
            }
        }
        catch {
            Write-Host " ERROR" -ForegroundColor Red
            Write-Host "    $_" -ForegroundColor DarkRed
            $results.Failed += $type
        }
    }
    else {
        Write-Host " SKIPPED (WhatIf)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host ("-" * 50) -ForegroundColor Gray
Write-Host ""

# Summary
Write-Host "BACKUP SUMMARY" -ForegroundColor White
Write-Host ""

if ($results.Success.Count -gt 0) {
    $totalItems = ($results.Success | Measure-Object -Property Items -Sum).Sum
    $totalSize = ($results.Success | Measure-Object -Property Size -Sum).Sum
    $totalSizeDisplay = if ($totalSize -gt 1MB) {
        "{0:N2} MB" -f ($totalSize / 1MB)
    }
    elseif ($totalSize -gt 1KB) {
        "{0:N1} KB" -f ($totalSize / 1KB)
    }
    else {
        "$totalSize bytes"
    }
    
    Write-Host "  Successful: " -NoNewline
    Write-Host "$($results.Success.Count) files" -ForegroundColor Green
    Write-Host "  Total items: $totalItems" -ForegroundColor Gray
    Write-Host "  Total size:  $totalSizeDisplay" -ForegroundColor Gray
}

if ($results.Failed.Count -gt 0) {
    Write-Host "  Failed:     " -NoNewline
    Write-Host "$($results.Failed.Count) files" -ForegroundColor Red
    Write-Host "  Types: $($results.Failed -join ', ')" -ForegroundColor DarkRed
}

Write-Host ""

if ($results.Failed.Count -eq 0) {
    Write-Host "Backup completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Backup folder:" -ForegroundColor Gray
    Write-Host "  $backupFolder" -ForegroundColor Cyan
    Write-Host ""
    
    # List files
    Write-Host "Files created:" -ForegroundColor Gray
    $results.Success | ForEach-Object {
        $sizeDisplay = if ($_.Size -gt 1KB) {
            "{0:N1} KB" -f ($_.Size / 1KB)
        }
        else {
            "$($_.Size) bytes"
        }
        Write-Host "  - $($_.Type).json ($($_.Items) items, $sizeDisplay)" -ForegroundColor Gray
    }
    Write-Host ""
    
    exit 0
}
else {
    Write-Host "Backup completed with errors." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
