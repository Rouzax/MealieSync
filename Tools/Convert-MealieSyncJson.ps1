#Requires -Version 7.0
<#
.SYNOPSIS
    Convert legacy JSON files to new MealieSync format
.DESCRIPTION
    Migrates JSON files from the legacy raw array format to the new 
    MealieSync wrapper format with $schema, $type, and $version metadata.

    The new format is REQUIRED for import operations. This tool helps
    convert existing data files.

    Legacy format (raw array):
    [
        { "id": "...", "name": "tomaat" },
        { "id": "...", "name": "ui" }
    ]

    New format (with wrapper):
    {
        "$schema": "mealie-sync",
        "$type": "Foods",
        "$version": "1.0",
        "items": [
            { "id": "...", "name": "tomaat" },
            { "id": "...", "name": "ui" }
        ]
    }

.PARAMETER Path
    Path to a single JSON file to convert
.PARAMETER Folder
    Path to a folder containing JSON files to convert
.PARAMETER Type
    The data type for the file(s): Foods, Units, Labels, Categories, Tags, Tools
.PARAMETER OutputPath
    Optional output path. If not specified, files are updated in-place with .bak backup
.PARAMETER Force
    Overwrite output files without confirmation
.PARAMETER WhatIf
    Show what would be converted without making changes
.EXAMPLE
    .\Tools\Convert-MealieSyncJson.ps1 -Path .\Foods.json -Type Foods
    # Converts single file, creates Foods.json.bak backup
.EXAMPLE
    .\Tools\Convert-MealieSyncJson.ps1 -Folder .\Data\Labels -Type Foods
    # Converts all JSON files in folder
.EXAMPLE
    .\Tools\Convert-MealieSyncJson.ps1 -Path .\old\Foods.json -Type Foods -OutputPath .\new\Foods.json
    # Converts to new location without modifying original
.EXAMPLE
    .\Tools\Convert-MealieSyncJson.ps1 -Path .\Foods.json -Type Foods -WhatIf
    # Preview conversion without making changes
.NOTES
    Author: MealieSync Project
    Version: 2.0.0
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'SingleFile')]
param(
    [Parameter(ParameterSetName = 'SingleFile', Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$Path,
    
    [Parameter(ParameterSetName = 'Folder', Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$Folder,
    
    [Parameter(Mandatory)]
    [ValidateSet('Foods', 'Units', 'Labels', 'Categories', 'Tags', 'Tools')]
    [string]$Type,
    
    [string]$OutputPath,
    
    [switch]$Force
)

# ============================================================================
# Helper Functions
# ============================================================================

function Test-LegacyFormat {
    param([object]$Data)
    
    # New format has wrapper properties
    if ($Data.PSObject.Properties.Name -contains '$schema' -and
        $Data.PSObject.Properties.Name -contains '$type' -and
        $Data.PSObject.Properties.Name -contains '$version') {
        return $false  # Already new format
    }
    
    # Legacy format is typically an array
    if ($Data -is [array]) {
        return $true
    }
    
    # Could be a single object wrapped in JSON
    return $true
}

function Convert-ToNewFormat {
    param(
        [object]$Data,
        [string]$Type
    )
    
    # Ensure items is an array
    $items = if ($Data -is [array]) {
        @($Data)
    }
    else {
        @($Data)
    }
    
    # Build new format wrapper
    $wrapper = [ordered]@{
        '$schema'  = 'mealie-sync'
        '$type'    = $Type
        '$version' = '1.0'
        'items'    = $items
    }
    
    return $wrapper
}

function Clean-ItemFields {
    param(
        [object]$Item,
        [string]$Type
    )
    
    # Create clean copy without unwanted fields
    $clean = [ordered]@{}
    
    # Define fields to keep per type
    $keepFields = switch ($Type) {
        'Foods' {
            @('id', 'name', 'pluralName', 'description', 'label', 'aliases', 'householdsWithIngredientFood')
        }
        'Units' {
            @('id', 'name', 'pluralName', 'description', 'abbreviation', 'pluralAbbreviation', 
              'useAbbreviation', 'fraction', 'aliases')
        }
        'Labels' {
            @('id', 'name', 'color')
        }
        'Categories' {
            @('id', 'name')
        }
        'Tags' {
            @('id', 'name')
        }
        'Tools' {
            @('id', 'name', 'householdsWithTool')
        }
    }
    
    # Fields to always remove
    $removeFields = @('groupId', 'slug', 'labelId', 'extras', 'createdAt', 'updatedAt')
    
    foreach ($prop in $Item.PSObject.Properties) {
        $name = $prop.Name
        
        # Skip fields to remove
        if ($name -in $removeFields) {
            continue
        }
        
        # Keep only allowed fields (if defined) or all non-removed fields
        if ($keepFields.Count -eq 0 -or $name -in $keepFields) {
            $clean[$name] = $prop.Value
        }
    }
    
    # Special handling for label field in Foods
    if ($Type -eq 'Foods' -and $Item.label) {
        # Keep only label name, not the full object
        if ($Item.label.PSObject.Properties.Name -contains 'name') {
            $clean['label'] = $Item.label.name
        }
    }
    
    return $clean
}

function Convert-JsonFile {
    param(
        [string]$FilePath,
        [string]$Type,
        [string]$OutputFile,
        [switch]$WhatIf
    )
    
    $fileName = Split-Path $FilePath -Leaf
    
    # Read and parse JSON
    try {
        $content = Get-Content $FilePath -Raw -Encoding UTF8
        $data = $content | ConvertFrom-Json
    }
    catch {
        Write-Host "  ✗ $fileName - Failed to parse JSON: $_" -ForegroundColor Red
        return @{ Success = $false; Reason = "Parse error" }
    }
    
    # Check if already new format
    if (-not (Test-LegacyFormat -Data $data)) {
        # Verify type matches
        $existingType = $data.'$type'
        if ($existingType -eq $Type) {
            Write-Host "  ○ $fileName - Already in new format ($Type)" -ForegroundColor Gray
            return @{ Success = $true; Reason = "Already converted"; Skipped = $true }
        }
        else {
            Write-Host "  ⚠ $fileName - Already converted but type is '$existingType', expected '$Type'" -ForegroundColor Yellow
            return @{ Success = $false; Reason = "Type mismatch" }
        }
    }
    
    # Get items count
    $itemCount = if ($data -is [array]) { $data.Count } else { 1 }
    
    if ($WhatIf) {
        Write-Host "  → $fileName - Would convert $itemCount items to $Type format" -ForegroundColor Cyan
        return @{ Success = $true; Reason = "WhatIf"; Items = $itemCount }
    }
    
    # Convert to new format
    $newData = Convert-ToNewFormat -Data $data -Type $Type
    
    # Clean up individual items
    $cleanedItems = @()
    foreach ($item in $newData.items) {
        $cleanedItems += Clean-ItemFields -Item $item -Type $Type
    }
    $newData.items = $cleanedItems
    
    # Determine output path
    $targetPath = if ($OutputFile) { $OutputFile } else { $FilePath }
    
    # Create backup if overwriting
    if ($targetPath -eq $FilePath) {
        $backupPath = "$FilePath.bak"
        Copy-Item -Path $FilePath -Destination $backupPath -Force
    }
    
    # Write new format
    try {
        $json = $newData | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($targetPath, $json, [System.Text.UTF8Encoding]::new($false))
        
        Write-Host "  ✓ $fileName - Converted $itemCount items" -ForegroundColor Green
        if ($targetPath -eq $FilePath) {
            Write-Host "    Backup: $backupPath" -ForegroundColor DarkGray
        }
        
        return @{ Success = $true; Items = $itemCount }
    }
    catch {
        Write-Host "  ✗ $fileName - Failed to write: $_" -ForegroundColor Red
        return @{ Success = $false; Reason = "Write error" }
    }
}

# ============================================================================
# Main Script
# ============================================================================

Write-Host ""
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host "   MEALIESYNC JSON MIGRATION" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host ""

# Collect files to process
$files = @()

if ($PSCmdlet.ParameterSetName -eq 'SingleFile') {
    $files += Get-Item $Path
    Write-Host "Source: $Path" -ForegroundColor Gray
}
else {
    $files += Get-ChildItem -Path $Folder -Filter '*.json' -File
    Write-Host "Source folder: $Folder" -ForegroundColor Gray
    Write-Host "Found: $($files.Count) JSON files" -ForegroundColor Gray
}

Write-Host "Target type: $Type" -ForegroundColor Gray

if ($OutputPath -and $PSCmdlet.ParameterSetName -eq 'SingleFile') {
    Write-Host "Output: $OutputPath" -ForegroundColor Gray
}
elseif (-not $OutputPath) {
    Write-Host "Mode: In-place with .bak backup" -ForegroundColor Gray
}

Write-Host ""
Write-Host ("-" * 50) -ForegroundColor Gray
Write-Host ""

if ($files.Count -eq 0) {
    Write-Host "No JSON files found to convert." -ForegroundColor Yellow
    exit 0
}

# Process files
$stats = @{
    Total     = $files.Count
    Converted = 0
    Skipped   = 0
    Failed    = 0
    Items     = 0
}

foreach ($file in $files) {
    $outPath = if ($OutputPath -and $PSCmdlet.ParameterSetName -eq 'SingleFile') {
        $OutputPath
    }
    elseif ($OutputPath -and $PSCmdlet.ParameterSetName -eq 'Folder') {
        Join-Path $OutputPath $file.Name
    }
    else {
        $null
    }
    
    $result = Convert-JsonFile -FilePath $file.FullName -Type $Type -OutputFile $outPath -WhatIf:$WhatIfPreference
    
    if ($result.Success) {
        if ($result.Skipped) {
            $stats.Skipped++
        }
        else {
            $stats.Converted++
            $stats.Items += $result.Items
        }
    }
    else {
        $stats.Failed++
    }
}

# Summary
Write-Host ""
Write-Host ("-" * 50) -ForegroundColor Gray
Write-Host ""
Write-Host "SUMMARY" -ForegroundColor White
Write-Host ""
Write-Host "  Total files:    $($stats.Total)" -ForegroundColor Gray
Write-Host "  Converted:      $($stats.Converted)" -ForegroundColor Green
Write-Host "  Already done:   $($stats.Skipped)" -ForegroundColor Gray
Write-Host "  Failed:         $($stats.Failed)" -ForegroundColor $(if ($stats.Failed -gt 0) { "Red" } else { "Gray" })
Write-Host "  Total items:    $($stats.Items)" -ForegroundColor Cyan
Write-Host ""

if ($WhatIfPreference) {
    Write-Host "This was a preview. Run without -WhatIf to apply changes." -ForegroundColor Yellow
    Write-Host ""
}

if ($stats.Failed -gt 0) {
    exit 1
}
exit 0
