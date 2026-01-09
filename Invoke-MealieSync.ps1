#Requires -Version 7.0
<#
.SYNOPSIS
    Sync Foods and Units data with Mealie
.DESCRIPTION
    Main script to import, export, and synchronize Foods and Units with your Mealie instance.
    Requires PowerShell 7.0 or later (PowerShell Core).
    
    Actions:
    - List   : Display items from Mealie
    - Export : Export items to JSON file(s)
    - Import : Import items from JSON (add new, optionally update existing)
    - Mirror : Full sync - add, update, AND DELETE to match JSON exactly
    
.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Data\Dutch_Foods.json
    Import foods from JSON file (create only, skip existing)

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Import -Type Foods -Folder .\Data\Labels
    Import all JSON files from a folder

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting
    Import foods and update any existing entries

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting -ReplaceAliases
    Import foods, update existing, and replace aliases instead of merging

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Export -Type Units -JsonPath .\Exports\Units_backup.json
    Export all units to JSON file

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Export -Type Foods -JsonPath .\Exports\Groente.json -Label "Groente"
    Export only foods with label "Groente"

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Export -Type Foods -JsonPath .\Data\Labels -SplitByLabel
    Export foods to separate files per label (Groente.json, Vlees.json, etc.)

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -JsonPath .\Foods.json -WhatIf
    Preview what would be added, updated, and DELETED (safe preview)

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -JsonPath .\Foods.json -Force
    Full sync: add, update, and DELETE to match JSON exactly (no confirmation)

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Mirror -Type Foods -Folder .\Data\Labels -WhatIf
    Preview folder sync with automatic cross-file conflict detection

.EXAMPLE
    .\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -WhatIf
    Preview what would happen without making changes
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Import', 'Export', 'List', 'Mirror')]
    [string]$Action,
    
    [Parameter(Mandatory)]
    [ValidateSet('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools')]
    [string]$Type,
    
    [string]$JsonPath,
    
    # Import option: import all JSON files from a folder
    # For Foods/Units: automatic cross-file conflict detection before import
    [string]$Folder,
    
    # Import/Mirror: update existing items
    [switch]$UpdateExisting,
    
    # Import/Mirror: replace aliases instead of merging (Foods, Units)
    [switch]$ReplaceAliases,
    
    # Import/Mirror: skip automatic backup
    [switch]$SkipBackup,
    
    # Mirror: skip confirmation prompt for deletions
    [switch]$Force,
    
    # Export options for Foods
    [string]$Label,
    
    [switch]$SplitByLabel,
    
    [string]$ConfigPath = ".\mealie-config.json"
)

# Import the module
$modulePath = Join-Path $PSScriptRoot 'MealieApi.psm1'
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}
else {
    throw "Module not found: $modulePath"
}

# Load or create configuration
function Get-MealieConfig {
    param([string]$Path)
    
    if (Test-Path $Path) {
        $config = Get-Content $Path -Raw | ConvertFrom-Json
        return $config
    }
    else {
        Write-Host "Configuration file not found. Creating template..." -ForegroundColor Yellow
        
        $template = @{
            BaseUrl = "http://localhost:9000"
            Token   = "YOUR_API_TOKEN_HERE"
        }
        
        $template | ConvertTo-Json | Set-Content $Path -Encoding UTF8
        Write-Host "Created config template at: $Path" -ForegroundColor Cyan
        Write-Host "Please edit the file with your Mealie URL and API token." -ForegroundColor Cyan
        Write-Host "`nTo get your API token:"
        Write-Host "  1. Go to your Mealie instance"
        Write-Host "  2. Navigate to: /user/profile/api-tokens"
        Write-Host "  3. Create a new token and copy it to the config file"
        exit 1
    }
}

# Main execution
try {
    # Get configuration
    $configFullPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
        $ConfigPath
    }
    else {
        Join-Path $PSScriptRoot $ConfigPath
    }
    
    $config = Get-MealieConfig -Path $configFullPath
    
    if ($config.Token -eq "YOUR_API_TOKEN_HERE") {
        Write-Error "Please configure your API token in: $configFullPath"
        exit 1
    }
    
    # Initialize API
    Write-Host "Connecting to Mealie at: $($config.BaseUrl)" -ForegroundColor Cyan
    $connected = Initialize-MealieApi -BaseUrl $config.BaseUrl -Token $config.Token
    
    if (-not $connected) {
        exit 1
    }
    
    # Execute action
    switch ($Action) {
        'Import' {
            # Validate: need either JsonPath or Folder
            if (-not $JsonPath -and -not $Folder) {
                throw "Either -JsonPath or -Folder is required for Import action"
            }
            
            if ($JsonPath -and $Folder) {
                throw "Use either -JsonPath or -Folder, not both"
            }
            
            # Show import mode
            Write-Host ""
            Write-Host "Import mode:" -ForegroundColor Cyan
            if ($UpdateExisting) {
                Write-Host "  [X] Update existing items" -ForegroundColor Green
            }
            else {
                Write-Host "  [ ] Update existing items (use -UpdateExisting to enable)" -ForegroundColor DarkGray
            }
            if ($ReplaceAliases) {
                Write-Host "  [X] Replace aliases" -ForegroundColor Green
            }
            else {
                Write-Host "  [ ] Replace aliases (merge mode, use -ReplaceAliases to replace)" -ForegroundColor DarkGray
            }
            if ($Label -and $Type -eq 'Foods') {
                Write-Host "  [X] Label filter: $Label" -ForegroundColor Green
            }
            Write-Host ""
            
            $importParams = @{
                BasePath = $PSScriptRoot
            }
            
            if ($UpdateExisting) {
                $importParams.UpdateExisting = $true
            }
            
            if ($ReplaceAliases) {
                $importParams.ReplaceAliases = $true
            }
            
            if ($SkipBackup) {
                $importParams.SkipBackup = $true
            }
            
            if ($WhatIfPreference) {
                $importParams.WhatIf = $true
            }
            
            # Label filtering for Foods
            if ($Label -and $Type -eq 'Foods') {
                $importParams.Label = $Label
            }
            
            if ($Folder) {
                # Import all JSON files from folder (with automatic conflict checking for Foods/Units)
                $folderPath = if ([System.IO.Path]::IsPathRooted($Folder)) {
                    $Folder
                }
                else {
                    Join-Path (Get-Location) $Folder
                }
                
                if (-not (Test-Path $folderPath -PathType Container)) {
                    throw "Folder not found: $folderPath"
                }
                
                # For Foods and Units, use the new -Folder parameter which includes conflict checking
                if ($Type -in @('Foods', 'Units')) {
                    $importParams.Folder = $folderPath
                    
                    $null = switch ($Type) {
                        'Foods' { Import-MealieFoods @importParams }
                        'Units' { Import-MealieUnits @importParams }
                    }
                }
                else {
                    # For other types, process files individually (no conflict detection needed)
                    $jsonFiles = Get-ChildItem -Path $folderPath -Filter "*.json" | Sort-Object Name
                    
                    if ($jsonFiles.Count -eq 0) {
                        Write-Warning "No JSON files found in: $folderPath"
                        return
                    }
                    
                    Write-Host "`nImporting $Type from folder: $folderPath" -ForegroundColor Cyan
                    Write-Host "Found $($jsonFiles.Count) JSON file(s)`n" -ForegroundColor Cyan
                    
                    # Create a single backup before processing all files (unless -SkipBackup or -WhatIf)
                    if (-not $SkipBackup -and -not $WhatIfPreference) {
                        $backupPath = Backup-BeforeImport -Type $Type -BasePath $PSScriptRoot
                        if ($backupPath) {
                            Write-Host "Backup created: $backupPath`n" -ForegroundColor DarkGray
                        }
                    }
                    
                    # Force SkipBackup for individual file imports (backup already done above)
                    $importParams.SkipBackup = $true
                    
                    # Combined stats
                    $totalStats = @{
                        Created       = 0
                        Updated       = 0
                        Unchanged     = 0
                        Skipped       = 0
                        Errors        = 0
                        LabelWarnings = 0
                        Conflicts     = 0
                        Deleted       = 0
                    }
                    
                    foreach ($file in $jsonFiles) {
                        Write-Host "── $($file.Name) ──" -ForegroundColor White
                        $importParams.Path = $file.FullName
                        
                        $result = switch ($Type) {
                            'Labels' { Import-MealieLabels @importParams }
                            'Categories' { Import-MealieOrganizers @importParams -Type 'Categories' }
                            'Tags' { Import-MealieOrganizers @importParams -Type 'Tags' }
                            'Tools' { Import-MealieOrganizers @importParams -Type 'Tools' }
                        }
                        
                        # Aggregate stats
                        if ($result) {
                            $totalStats.Created += $result.Created
                            $totalStats.Updated += $result.Updated
                            $totalStats.Unchanged += $result.Unchanged
                            $totalStats.Skipped += $result.Skipped
                            $totalStats.Errors += $result.Errors
                            if ($result.LabelWarnings) {
                                $totalStats.LabelWarnings += $result.LabelWarnings
                            }
                            if ($result.Conflicts) {
                                $totalStats.Conflicts += $result.Conflicts
                            }
                            if ($result.Deleted) {
                                $totalStats.Deleted += $result.Deleted
                            }
                        }
                        
                        Write-Host ""
                    }
                    
                    # Show combined totals
                    Write-Host "═══════════════════════════════════" -ForegroundColor Cyan
                    Write-Host "Combined Totals ($($jsonFiles.Count) files):" -ForegroundColor Cyan
                    Write-Host "  Created:       $($totalStats.Created)"
                    Write-Host "  Updated:       $($totalStats.Updated)"
                    Write-Host "  Unchanged:     $($totalStats.Unchanged)"
                    Write-Host "  Skipped:       $($totalStats.Skipped)"
                    Write-Host "  Errors:        $($totalStats.Errors)"
                    if ($totalStats.LabelWarnings -gt 0) {
                        Write-Host "  LabelWarnings: $($totalStats.LabelWarnings)" -ForegroundColor Yellow
                    }
                    if ($totalStats.Conflicts -gt 0) {
                        Write-Host "  Conflicts:     $($totalStats.Conflicts)" -ForegroundColor Red
                    }
                    if ($totalStats.Deleted -gt 0) {
                        Write-Host "  Deleted:       $($totalStats.Deleted)" -ForegroundColor Magenta
                    }
                }
            }
            else {
                # Import single file (existing behavior)
                $fullPath = if ([System.IO.Path]::IsPathRooted($JsonPath)) {
                    $JsonPath
                }
                else {
                    Join-Path (Get-Location) $JsonPath
                }
                
                Write-Host "`nImporting $Type from: $fullPath" -ForegroundColor Cyan
                
                $importParams.Path = $fullPath
                
                $null = switch ($Type) {
                    'Foods' { Import-MealieFoods @importParams }
                    'Units' { Import-MealieUnits @importParams }
                    'Labels' { Import-MealieLabels @importParams }
                    'Categories' { Import-MealieOrganizers @importParams -Type 'Categories' }
                    'Tags' { Import-MealieOrganizers @importParams -Type 'Tags' }
                    'Tools' { Import-MealieOrganizers @importParams -Type 'Tools' }
                }
            }
        }
        
        'Export' {
            # For SplitByLabel, allow either -JsonPath or -Folder
            $exportPath = if ($SplitByLabel -and $Folder -and -not $JsonPath) {
                $Folder
            }
            else {
                $JsonPath
            }
            
            if (-not $exportPath) {
                throw "JsonPath is required for Export action (or -Folder when using -SplitByLabel)"
            }
            
            $fullPath = if ([System.IO.Path]::IsPathRooted($exportPath)) {
                $exportPath
            }
            else {
                Join-Path (Get-Location) $exportPath
            }
            
            if ($SplitByLabel) {
                Write-Host "`nExporting $Type to folder: $fullPath (split by label)" -ForegroundColor Cyan
            }
            elseif ($Label) {
                Write-Host "`nExporting $Type with label '$Label' to: $fullPath" -ForegroundColor Cyan
            }
            else {
                Write-Host "`nExporting $Type to: $fullPath" -ForegroundColor Cyan
            }
            
            # Build export params with WhatIf support
            $exportParams = @{ Path = $fullPath }
            if ($WhatIfPreference) {
                $exportParams.WhatIf = $true
            }
            
            switch ($Type) {
                'Foods' {
                    if ($Label) { $exportParams.Label = $Label }
                    if ($SplitByLabel) { $exportParams.SplitByLabel = $true }
                    Export-MealieFoods @exportParams
                }
                'Units' { Export-MealieUnits @exportParams }
                'Labels' { Export-MealieLabels @exportParams }
                'Categories' { Export-MealieCategories @exportParams }
                'Tags' { Export-MealieTags @exportParams }
                'Tools' { Export-MealieTools @exportParams }
            }
        }
        
        'List' {
            Write-Host "`nListing $Type from Mealie:" -ForegroundColor Cyan
            
            switch ($Type) {
                'Foods' {
                    $items = Get-MealieFoods -All
                    $items | Select-Object name, pluralName, @{N = 'label'; E = { $_.label.name } }, @{N = 'aliases'; E = { ($_.aliases.name -join ', ') } } | 
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) foods"
                }
                'Units' {
                    $items = Get-MealieUnits -All
                    $items | Select-Object name, pluralName, abbreviation, @{N = 'aliases'; E = { ($_.aliases.name -join ', ') } } |
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) units"
                }
                'Labels' {
                    $items = Get-MealieLabels -All
                    $items | Select-Object name, color |
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) labels"
                }
                'Categories' {
                    $items = Get-MealieCategories -All
                    $items | Select-Object name, slug |
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) categories"
                }
                'Tags' {
                    $items = Get-MealieTags -All
                    $items | Select-Object name, slug |
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) tags"
                }
                'Tools' {
                    $items = Get-MealieTools -All
                    $items | Select-Object name, slug |
                        Sort-Object name |
                        Format-Table -AutoSize
                    Write-Host "Total: $($items.Count) tools"
                }
            }
        }
        
        'Mirror' {
            # Mirror = Full sync: add, update, AND delete
            if (-not $JsonPath -and -not $Folder) {
                throw "Either -JsonPath or -Folder is required for Mirror action"
            }
            
            if ($JsonPath -and $Folder) {
                throw "Use either -JsonPath or -Folder, not both"
            }
            
            # Build parameters for Sync functions
            $syncParams = @{
                BasePath = $PSScriptRoot
            }
            
            if ($ReplaceAliases -and $Type -in @('Foods', 'Units')) {
                $syncParams.ReplaceAliases = $true
            }
            
            if ($SkipBackup) {
                $syncParams.SkipBackup = $true
            }
            
            if ($Force) {
                $syncParams.Force = $true
            }
            
            if ($WhatIfPreference) {
                $syncParams.WhatIf = $true
            }
            
            # Label scoping for Foods
            if ($Label -and $Type -eq 'Foods') {
                $syncParams.Label = $Label
            }
            
            if ($Folder) {
                # Folder-based Mirror (with automatic conflict checking for Foods/Units)
                $folderPath = if ([System.IO.Path]::IsPathRooted($Folder)) {
                    $Folder
                }
                else {
                    Join-Path (Get-Location) $Folder
                }
                
                if (-not (Test-Path $folderPath -PathType Container)) {
                    throw "Folder not found: $folderPath"
                }
                
                # For Foods and Units, use the new -Folder parameter which includes conflict checking
                if ($Type -in @('Foods', 'Units')) {
                    $syncParams.Folder = $folderPath
                    
                    $null = switch ($Type) {
                        'Foods' { Sync-MealieFoods @syncParams }
                        'Units' { Sync-MealieUnits @syncParams }
                    }
                }
                else {
                    # For other types, folder Mirror is not supported (too complex for Label-less types)
                    throw "Folder Mirror is only supported for Foods and Units. Use -JsonPath for $Type."
                }
            }
            else {
                # Single file Mirror (existing behavior)
                $fullPath = if ([System.IO.Path]::IsPathRooted($JsonPath)) {
                    $JsonPath
                }
                else {
                    Join-Path (Get-Location) $JsonPath
                }
                
                Write-Host "`nMirroring $Type to match: $fullPath" -ForegroundColor Cyan
                
                $syncParams.Path = $fullPath
                
                # Call appropriate Sync function
                $null = switch ($Type) {
                    'Foods' { Sync-MealieFoods @syncParams }
                    'Units' { Sync-MealieUnits @syncParams }
                    'Labels' { Sync-MealieLabels @syncParams }
                    'Categories' { Sync-MealieCategories @syncParams }
                    'Tags' { Sync-MealieTags @syncParams }
                    'Tools' { Sync-MealieTools @syncParams }
                }
            }
        }
    }
    
    Write-Host "`nDone!" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}