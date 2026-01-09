#Requires -Version 7.0
<#
.SYNOPSIS
    Test for cross-file conflicts in food JSON files
.DESCRIPTION
    Scans multiple JSON files for naming conflicts that would cause import problems.
    Detects duplicate names, pluralNames, and aliases across files before import.
.NOTES
    Part of MealieSync module - see README.md for usage examples.
#>

function Test-MealieFoodConflicts {
    <#
    .SYNOPSIS
        Detect naming conflicts in food JSON files
    .DESCRIPTION
        Scans food JSON files for conflicts that would cause import problems:
        - Same name appearing multiple times (within or across files)
        - Name in one item matching pluralName in another
        - Name or pluralName matching an alias in another item
        - Same alias appearing multiple times
        
        Run this before importing JSON files to catch duplicates
        caused by AI-assisted categorization or manual editing errors.
    .PARAMETER Path
        One or more paths to JSON files. Supports wildcards.
        Example: ".\Foods\*.json" or @("Groente.json", "Fruit.json")
    .PARAMETER Folder
        Path to a folder containing JSON files
    .PARAMETER Recurse
        When using -Folder, also search subdirectories
    .PARAMETER Quiet
        Suppress console output; return result object only
    .EXAMPLE
        Test-MealieFoodConflicts -Path ".\Foods\*.json"
        # Check all JSON files in the Foods folder
    .EXAMPLE
        Test-MealieFoodConflicts -Folder ".\FoodCategories" -Recurse
        # Check all JSON files in folder and subfolders
    .EXAMPLE
        $result = Test-MealieFoodConflicts -Path @("Groente.json", "Fruit.json") -Quiet
        if ($result.HasConflicts) {
            Write-Error "Found $($result.ConflictCount) conflicts!"
        }
    .EXAMPLE
        # Check before import
        $check = Test-MealieFoodConflicts -Folder ".\Foods" -Quiet
        if (-not $check.HasConflicts) {
            Get-ChildItem ".\Foods\*.json" | ForEach-Object {
                Import-MealieFoods -Path $_.FullName -UpdateExisting
            }
        }
    .OUTPUTS
        [hashtable] @{
            HasConflicts     = [bool]   # True if any conflicts found
            ConflictCount    = [int]    # Number of unique conflicting values
            WithinFileCount  = [int]    # Conflicts within single files
            CrossFileCount   = [int]    # Conflicts across multiple files
            FilesScanned     = [int]    # Number of files checked
            ItemsScanned     = [int]    # Total items across all files
            Conflicts        = [array]  # Detailed conflict information
        }
        
        Each conflict in the Conflicts array:
        @{
            Value = "conflicting value"
            Scope = "WithinFile" | "CrossFile"
            Occurrences = @(
                @{ File = "filename"; Field = "name|pluralName|alias"; ItemName = "item name" }
            )
        }
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path', Position = 0)]
        [SupportsWildcards()]
        [string[]]$Path,
        
        [Parameter(Mandatory, ParameterSetName = 'Folder')]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Folder,
        
        [Parameter(ParameterSetName = 'Folder')]
        [switch]$Recurse,
        
        [switch]$Quiet
    )
    
    # Resolve files based on parameter set
    $jsonFiles = @()
    
    if ($PSCmdlet.ParameterSetName -eq 'Folder') {
        $searchParams = @{
            Path   = $Folder
            Filter = "*.json"
        }
        if ($Recurse) {
            $searchParams.Recurse = $true
        }
        $jsonFiles = @(Get-ChildItem @searchParams | Where-Object { -not $_.PSIsContainer })
    }
    else {
        # Resolve wildcards in paths
        foreach ($p in $Path) {
            $resolved = @(Get-ChildItem -Path $p -File -ErrorAction SilentlyContinue)
            if ($resolved.Count -eq 0) {
                Write-Warning "No files found matching: $p"
            }
            $jsonFiles += $resolved
        }
    }
    
    # Check we have files to process
    if ($jsonFiles.Count -eq 0) {
        $emptyResult = @{
            HasConflicts  = $false
            ConflictCount = 0
            FilesScanned  = 0
            ItemsScanned  = 0
            Conflicts     = @()
        }
        
        if (-not $Quiet) {
            Write-Warning "No JSON files found to check."
        }
        
        return $emptyResult
    }
    
    if ($jsonFiles.Count -eq 1) {
        Write-Verbose "Checking single file for internal conflicts"
    }
    
    # Load items from each file
    $itemSets = [System.Collections.ArrayList]::new()
    $loadErrors = @()
    
    foreach ($file in $jsonFiles) {
        try {
            Write-Verbose "Loading: $($file.FullName)"
            
            # Read and parse JSON
            $rawContent = Get-Content $file.FullName -Raw -Encoding UTF8
            $data = $rawContent | ConvertFrom-Json
            
            # Extract items (handle both wrapper format and raw array)
            $items = @()
            if ($data -is [array]) {
                $items = $data
            }
            elseif ($data.items) {
                $items = $data.items
            }
            elseif ($data.PSObject.Properties.Name -contains 'items') {
                $items = @($data.items)
            }
            else {
                # Try to treat the object as a single item
                Write-Warning "Unexpected format in $($file.Name) - skipping"
                continue
            }
            
            # Skip empty files
            if ($items.Count -eq 0) {
                Write-Verbose "Skipping empty file: $($file.Name)"
                continue
            }
            
            [void]$itemSets.Add(@{
                FilePath = $file.FullName
                Items    = $items
            })
            
            Write-Verbose "Loaded $($items.Count) items from $($file.Name)"
        }
        catch {
            $loadErrors += "Failed to load $($file.Name): $_"
            Write-Warning "Failed to load $($file.Name): $_"
        }
    }
    
    # Check we have items to process
    if ($itemSets.Count -eq 0) {
        $emptyResult = @{
            HasConflicts  = $false
            ConflictCount = 0
            FilesScanned  = $jsonFiles.Count
            ItemsScanned  = 0
            Conflicts     = @()
            LoadErrors    = $loadErrors
        }
        
        if (-not $Quiet) {
            Write-Warning "No valid items found in any files."
        }
        
        return $emptyResult
    }
    
    # Find conflicts
    $conflicts = @(Find-ItemConflicts -ItemSets $itemSets -Type 'Foods')
    
    # Build summary
    $summary = Get-ConflictSummary -Conflicts $conflicts -ItemSets $itemSets
    
    # Display formatted report unless quiet
    if (-not $Quiet) {
        Format-ConflictReport -Conflicts $conflicts -Summary $summary -Type 'Foods'
    }
    
    # Build return object
    $result = @{
        HasConflicts     = $summary.HasConflicts
        ConflictCount    = $summary.ConflictCount
        WithinFileCount  = $summary.WithinFileCount
        CrossFileCount   = $summary.CrossFileCount
        FilesScanned     = $summary.FilesScanned
        ItemsScanned     = $summary.ItemsScanned
        Conflicts        = $conflicts
    }
    
    if ($loadErrors.Count -gt 0) {
        $result.LoadErrors = $loadErrors
    }
    
    return $result
}
