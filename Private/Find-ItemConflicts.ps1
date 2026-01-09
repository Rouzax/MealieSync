#Requires -Version 7.0
<#
.SYNOPSIS
    Item conflict detection helper for MealieSync
.DESCRIPTION
    Internal helper function that detects naming conflicts within and across
    JSON files before import. Prevents duplicate items from appearing in
    the same file or across different category files (common with AI-assisted 
    categorization).
.NOTES
    This is a private function file - not exported by the module.
    
    Test Scenarios:
    
    Scenario 1: Cross-file name collision
    File1: { "name": "tomaat" }, File2: { "name": "tomaat" }
    Expected: Conflict on "tomaat" (name ↔ name), Scope = CrossFile
    
    Scenario 2: Cross-file Name ↔ PluralName collision
    File1: { "name": "kers", "pluralName": "kersen" }
    File2: { "name": "kersen" }
    Expected: Conflict on "kersen" (pluralName in File1, name in File2), Scope = CrossFile
    
    Scenario 3: Cross-file alias collision
    File1: { "name": "bieslook", "aliases": [{ "name": "schnittlauch" }] }
    File2: { "name": "prei", "aliases": [{ "name": "bieslook" }] }
    Expected: Conflict on "bieslook" (name in File1, alias in File2), Scope = CrossFile
    
    Scenario 4: No conflicts
    File1: { "name": "tomaat" }, File2: { "name": "appel" }
    Expected: No conflicts
    
    Scenario 5: Cross-file same item (multi-field)
    File1: { "name": "ei", "pluralName": "eieren" }
    File2: { "name": "ei", "pluralName": "eieren" }
    Expected: Conflicts on both "ei" and "eieren", Scope = CrossFile
    
    Scenario 6: Case-insensitive matching
    File1: { "name": "Tomaat" }, File2: { "name": "tomaat" }
    Expected: Conflict on "tomaat" (case-insensitive match)
    
    Scenario 7: Within-file duplicate names
    File1: { "name": "tomaat" }, { "name": "tomaat" }
    Expected: Conflict on "tomaat", Scope = WithinFile
    
    Scenario 8: Within-file alias collision
    File1: { "name": "bieslook" }, { "name": "prei", "aliases": [{ "name": "bieslook" }] }
    Expected: Conflict on "bieslook" (name ↔ alias), Scope = WithinFile
#>

function Find-ItemConflicts {
    <#
    .SYNOPSIS
        Detect naming conflicts within and across item collections
    .DESCRIPTION
        Builds a master lookup of all name-like values (name, pluralName, aliases,
        and for units: abbreviation, pluralAbbreviation) across one or more files,
        then identifies any values that appear in more than one location.
        
        Conflicts are categorized by scope:
        - WithinFile: Duplicate values in the same file
        - CrossFile: Duplicate values across different files
        
        This function is the core logic shared by Test-MealieFoodConflicts and
        Test-MealieUnitConflicts.
    .PARAMETER ItemSets
        Array of hashtables, each containing:
        - FilePath: Path to the source file (for reporting)
        - Items: Array of item objects from that file
    .PARAMETER Type
        'Foods' or 'Units' - determines which fields to check for conflicts.
        Foods: name, pluralName, aliases
        Units: name, pluralName, aliases, abbreviation, pluralAbbreviation
    .OUTPUTS
        Array of conflict objects:
        @{
            Value = "conflicting value (lowercase)"
            Scope = "WithinFile" | "CrossFile"
            Occurrences = @(
                @{ File = "filename"; Field = "name|pluralName|alias|..."; ItemName = "item's name" }
                @{ File = "filename"; Field = "..."; ItemName = "..." }
            )
        }
        Returns empty array if no conflicts found.
    .EXAMPLE
        $itemSets = @(
            @{ FilePath = "Groente.json"; Items = $groenteItems }
            @{ FilePath = "Fruit.json"; Items = $fruitItems }
        )
        $conflicts = Find-ItemConflicts -ItemSets $itemSets -Type 'Foods'
        
        if ($conflicts.Count -gt 0) {
            Write-Host "Found $($conflicts.Count) conflict(s)"
        }
    .EXAMPLE
        # Check units across multiple files
        $unitSets = @(
            @{ FilePath = "VolumeUnits.json"; Items = $volumeUnits }
            @{ FilePath = "WeightUnits.json"; Items = $weightUnits }
        )
        $conflicts = Find-ItemConflicts -ItemSets $unitSets -Type 'Units'
    .EXAMPLE
        # Check a single file for internal conflicts
        $itemSets = @(
            @{ FilePath = "Foods.json"; Items = $foods }
        )
        $conflicts = Find-ItemConflicts -ItemSets $itemSets -Type 'Foods'
        $withinFile = $conflicts | Where-Object { $_.Scope -eq 'WithinFile' }
    .NOTES
        Normalization follows the pattern from Build-FoodLookups:
        - Lowercase
        - Trim whitespace
        - Skip empty/null values
        
        All cross-combinations are detected:
        - name ↔ name
        - name ↔ pluralName
        - name ↔ alias
        - pluralName ↔ pluralName
        - pluralName ↔ alias
        - alias ↔ alias
        - (for Units) abbreviation ↔ any
        - (for Units) pluralAbbreviation ↔ any
        
        Scope determination:
        - WithinFile: All occurrences are in the same file
        - CrossFile: Occurrences span multiple files
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [array]$ItemSets,
        
        [Parameter(Mandatory)]
        [ValidateSet('Foods', 'Units')]
        [string]$Type
    )
    
    # Master lookup: value (lowercase) → array of occurrences
    # Each occurrence: @{ File; Field; ItemName; ItemId }
    $masterLookup = @{}
    
    # Helper function to register a value in the lookup
    function Register-Value {
        param(
            [string]$Value,
            [string]$File,
            [string]$Field,
            [string]$ItemName,
            [string]$ItemId
        )
        
        # Skip null/empty values
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return
        }
        
        # Normalize: lowercase + trim (matches Build-FoodLookups pattern)
        $normalizedValue = $Value.ToLower().Trim()
        
        # Skip if still empty after normalization
        if ([string]::IsNullOrEmpty($normalizedValue)) {
            return
        }
        
        # Get just the filename for cleaner reporting
        $fileName = Split-Path -Leaf $File
        
        # Create occurrence record
        $occurrence = @{
            File     = $fileName
            FilePath = $File
            Field    = $Field
            ItemName = $ItemName
            ItemId   = $ItemId
        }
        
        # Add to master lookup
        if (-not $masterLookup.ContainsKey($normalizedValue)) {
            $masterLookup[$normalizedValue] = [System.Collections.ArrayList]::new()
        }
        
        [void]$masterLookup[$normalizedValue].Add($occurrence)
    }
    
    # Process each item set
    foreach ($itemSet in $ItemSets) {
        $filePath = $itemSet.FilePath
        $items = $itemSet.Items
        
        # Skip empty item sets
        if (-not $items -or $items.Count -eq 0) {
            Write-Verbose "Skipping empty item set: $filePath"
            continue
        }
        
        Write-Verbose "Processing $($items.Count) items from: $filePath"
        
        $itemIndex = 0
        foreach ($item in $items) {
            $itemIndex++
            
            # Get item's display name for reporting
            $itemName = if ($item.name) { $item.name } else { "(unnamed)" }
            
            # Unique identifier for this item (file + index)
            $itemId = "$filePath|$itemIndex"
            
            # Register name
            Register-Value -Value $item.name -File $filePath -Field 'name' -ItemName $itemName -ItemId $itemId
            
            # Register pluralName
            Register-Value -Value $item.pluralName -File $filePath -Field 'pluralName' -ItemName $itemName -ItemId $itemId
            
            # Register aliases
            if ($item.aliases -and $item.aliases.Count -gt 0) {
                foreach ($alias in $item.aliases) {
                    $aliasName = if ($alias -is [string]) { $alias } else { $alias.name }
                    Register-Value -Value $aliasName -File $filePath -Field 'alias' -ItemName $itemName -ItemId $itemId
                }
            }
            
            # For Units: also register abbreviations
            if ($Type -eq 'Units') {
                Register-Value -Value $item.abbreviation -File $filePath -Field 'abbreviation' -ItemName $itemName -ItemId $itemId
                Register-Value -Value $item.pluralAbbreviation -File $filePath -Field 'pluralAbbreviation' -ItemName $itemName -ItemId $itemId
            }
        }
    }
    
    # Find conflicts: entries with occurrences from 2+ different items
    $conflicts = [System.Collections.ArrayList]::new()
    
    foreach ($entry in $masterLookup.GetEnumerator()) {
        $value = $entry.Key
        $occurrences = $entry.Value
        
        # Skip if only one occurrence
        if ($occurrences.Count -lt 2) {
            continue
        }
        
        # Check if occurrences span multiple ITEMS (not just multiple fields of same item)
        $uniqueItemIds = $occurrences | ForEach-Object { $_.ItemId } | Select-Object -Unique
        
        if ($uniqueItemIds.Count -lt 2) {
            # All occurrences from same item (e.g., name == pluralName) - not a conflict
            Write-Verbose "Skipping same-item match: '$value' (name/pluralName match in same item)"
            continue
        }
        
        # Determine scope: within-file or cross-file
        $uniqueFiles = $occurrences | ForEach-Object { $_.FilePath } | Select-Object -Unique
        $scope = if ($uniqueFiles.Count -lt 2) { 'WithinFile' } else { 'CrossFile' }
        
        # Build conflict object with Scope
        $conflict = @{
            Value       = $value
            Scope       = $scope
            Occurrences = @($occurrences | ForEach-Object {
                @{
                    File     = $_.File
                    FilePath = $_.FilePath
                    Field    = $_.Field
                    ItemName = $_.ItemName
                }
            })
        }
        
        [void]$conflicts.Add($conflict)
    }
    
    # Sort conflicts alphabetically by value for consistent output
    $sortedConflicts = @($conflicts | Sort-Object { $_.Value })
    
    Write-Verbose "Found $($sortedConflicts.Count) conflict(s)"
    
    return $sortedConflicts
}

function Get-ConflictSummary {
    <#
    .SYNOPSIS
        Generate summary statistics from conflict detection results
    .DESCRIPTION
        Creates a summary object with counts and metadata about the conflict
        detection operation, useful for both display and programmatic use.
    .PARAMETER Conflicts
        Array of conflict objects from Find-ItemConflicts
    .PARAMETER ItemSets
        The original ItemSets array (for file/item counts)
    .OUTPUTS
        [hashtable] @{
            HasConflicts = [bool]
            ConflictCount = [int]
            WithinFileCount = [int]
            CrossFileCount = [int]
            FilesScanned = [int]
            ItemsScanned = [int]
            FileList = [array] # filenames only
        }
    .EXAMPLE
        $conflicts = Find-ItemConflicts -ItemSets $itemSets -Type 'Foods'
        $summary = Get-ConflictSummary -Conflicts $conflicts -ItemSets $itemSets
        
        if ($summary.HasConflicts) {
            Write-Host "Found $($summary.ConflictCount) conflicts across $($summary.FilesScanned) files"
        }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Conflicts,
        
        [Parameter(Mandatory)]
        [array]$ItemSets
    )
    
    # Count files and items
    $filesScanned = $ItemSets.Count
    $itemsScanned = ($ItemSets | ForEach-Object { $_.Items.Count } | Measure-Object -Sum).Sum
    $fileList = @($ItemSets | ForEach-Object { Split-Path -Leaf $_.FilePath })
    
    # Count by scope
    $withinFileCount = @($Conflicts | Where-Object { $_.Scope -eq 'WithinFile' }).Count
    $crossFileCount = @($Conflicts | Where-Object { $_.Scope -eq 'CrossFile' }).Count
    
    return @{
        HasConflicts     = ($Conflicts.Count -gt 0)
        ConflictCount    = $Conflicts.Count
        WithinFileCount  = $withinFileCount
        CrossFileCount   = $crossFileCount
        FilesScanned     = $filesScanned
        ItemsScanned     = if ($itemsScanned) { $itemsScanned } else { 0 }
        FileList         = $fileList
    }
}

function Format-ConflictReport {
    <#
    .SYNOPSIS
        Format conflicts for console display
    .DESCRIPTION
        Creates a formatted console output for item conflicts with
        clear visual hierarchy and color coding. Groups conflicts by
        scope (within-file vs cross-file).
    .PARAMETER Conflicts
        Array of conflict objects from Find-ItemConflicts
    .PARAMETER Summary
        Summary hashtable from Get-ConflictSummary
    .PARAMETER Type
        'Foods' or 'Units' - for header text
    .EXAMPLE
        $conflicts = Find-ItemConflicts -ItemSets $itemSets -Type 'Foods'
        $summary = Get-ConflictSummary -Conflicts $conflicts -ItemSets $itemSets
        Format-ConflictReport -Conflicts $conflicts -Summary $summary -Type 'Foods'
    .NOTES
        Output format:
        
        ═══════════════════════════════════════════
         Food Conflicts
        ═══════════════════════════════════════════
        
        ── Within-File Conflicts (1) ──
        
        CONFLICT 1: "tomaat"
          ├─ Groente.json:    name of "tomaat"
          └─ Groente.json:    name of "tomaat (gedroogd)"
        
        ── Cross-File Conflicts (1) ──
        
        CONFLICT 2: "kersen"
          ├─ Groente.json:    name of "kersen"
          └─ Fruit.json:      pluralName of "kers"
        
        ───────────────────────────────────────────
          Conflicts found : 2 (1 within-file, 1 cross-file)
          Files scanned   : 5
          Items scanned   : 847
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Conflicts,
        
        [Parameter(Mandatory)]
        [hashtable]$Summary,
        
        [Parameter(Mandatory)]
        [ValidateSet('Foods', 'Units')]
        [string]$Type
    )
    
    # Singular form for display
    $typeSingular = if ($Type -eq 'Foods') { 'Food' } else { 'Unit' }
    
    # Header (consistent with Write-ImportSummary style)
    $headerLine = '═' * 43
    $separatorLine = '─' * 43
    
    Write-Host ""
    Write-Host $headerLine -ForegroundColor DarkGray
    Write-Host " $typeSingular Conflicts" -ForegroundColor White
    Write-Host $headerLine -ForegroundColor DarkGray
    Write-Host ""
    
    if (-not $Summary.HasConflicts) {
        Write-Host "  No conflicts found." -ForegroundColor Green
        Write-Host ""
    }
    else {
        # Group conflicts by scope
        $withinFile = @($Conflicts | Where-Object { $_.Scope -eq 'WithinFile' })
        $crossFile = @($Conflicts | Where-Object { $_.Scope -eq 'CrossFile' })
        
        $conflictNum = 0
        
        # Helper function to display a conflict
        function Show-Conflict {
            param($conflict, [ref]$num)
            $num.Value++
            
            # Conflict header
            Write-Host "CONFLICT $($num.Value)" -ForegroundColor Yellow -NoNewline
            Write-Host ": " -NoNewline
            Write-Host "`"$($conflict.Value)`"" -ForegroundColor Cyan
            
            # List occurrences with tree structure
            $occCount = $conflict.Occurrences.Count
            for ($i = 0; $i -lt $occCount; $i++) {
                $occ = $conflict.Occurrences[$i]
                $isLast = ($i -eq $occCount - 1)
                
                # Tree connector
                $connector = if ($isLast) { '└─' } else { '├─' }
                
                # Format: "  ├─ Groente.json:    name of "kersen""
                $fileNamePadded = "$($occ.File):".PadRight(20)
                
                Write-Host "  $connector " -ForegroundColor DarkGray -NoNewline
                Write-Host $fileNamePadded -ForegroundColor White -NoNewline
                Write-Host "$($occ.Field)" -ForegroundColor Magenta -NoNewline
                Write-Host " of " -NoNewline
                Write-Host "`"$($occ.ItemName)`"" -ForegroundColor Gray
            }
            
            Write-Host ""
        }
        
        # Display within-file conflicts first (if any)
        if ($withinFile.Count -gt 0) {
            Write-Host "── Within-File Conflicts ($($withinFile.Count)) ──" -ForegroundColor DarkYellow
            Write-Host ""
            
            foreach ($conflict in $withinFile) {
                Show-Conflict -conflict $conflict -num ([ref]$conflictNum)
            }
        }
        
        # Display cross-file conflicts (if any)
        if ($crossFile.Count -gt 0) {
            Write-Host "── Cross-File Conflicts ($($crossFile.Count)) ──" -ForegroundColor DarkYellow
            Write-Host ""
            
            foreach ($conflict in $crossFile) {
                Show-Conflict -conflict $conflict -num ([ref]$conflictNum)
            }
        }
    }
    
    # Footer
    Write-Host $separatorLine -ForegroundColor DarkGray
    
    if ($Conflicts.Count -gt 0) {
        Write-Host "  Conflicts found : " -NoNewline
        Write-Host "$($Summary.ConflictCount)" -ForegroundColor Red -NoNewline
        
        # Show breakdown if we have both types
        if ($Summary.WithinFileCount -gt 0 -and $Summary.CrossFileCount -gt 0) {
            Write-Host " ($($Summary.WithinFileCount) within-file, $($Summary.CrossFileCount) cross-file)" -ForegroundColor DarkGray -NoNewline
        }
        Write-Host ""
    }
    else {
        Write-Host "  Conflicts found : " -NoNewline
        Write-Host "0" -ForegroundColor Green
    }
    
    Write-Host "  Files scanned   : $($Summary.FilesScanned)"
    Write-Host "  Items scanned   : $($Summary.ItemsScanned)"
    Write-Host ""
}
