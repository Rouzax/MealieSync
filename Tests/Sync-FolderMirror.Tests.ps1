#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'MealieApi.psm1'
    Import-Module $modulePath -Force
}

Describe 'Get-ItemsToDelete' {
    Context 'Combined vs per-file import items' {
        BeforeAll {
            $existingItems = @(
                [PSCustomObject]@{ id = '1'; name = 'tomato'; pluralName = 'tomatoes'; aliases = @() }
                [PSCustomObject]@{ id = '2'; name = 'potato'; pluralName = 'potatoes'; aliases = @() }
                [PSCustomObject]@{ id = '3'; name = 'carrot'; pluralName = 'carrots'; aliases = @() }
                [PSCustomObject]@{ id = '4'; name = 'onion'; pluralName = 'onions'; aliases = @() }
            )

            $file1Items = @(
                [PSCustomObject]@{ id = '1'; name = 'tomato'; pluralName = 'tomatoes'; aliases = @() }
                [PSCustomObject]@{ id = '2'; name = 'potato'; pluralName = 'potatoes'; aliases = @() }
            )

            $file2Items = @(
                [PSCustomObject]@{ id = '3'; name = 'carrot'; pluralName = 'carrots'; aliases = @() }
                [PSCustomObject]@{ id = '4'; name = 'onion'; pluralName = 'onions'; aliases = @() }
            )
        }

        It 'Per-file: each file sees items from other files as orphans' {
            $toDelete1 = @(Get-ItemsToDelete -ExistingItems $existingItems -ImportItems $file1Items -MatchById)
            $toDelete2 = @(Get-ItemsToDelete -ExistingItems $existingItems -ImportItems $file2Items -MatchById)

            $toDelete1.Count | Should -Be 2
            $toDelete2.Count | Should -Be 2
            ($toDelete1.Count + $toDelete2.Count) | Should -Be 4
        }

        It 'Combined: all files together produce zero orphans' {
            $combinedItems = $file1Items + $file2Items
            $toDelete = @(Get-ItemsToDelete -ExistingItems $existingItems -ImportItems $combinedItems -MatchById)

            $toDelete.Count | Should -Be 0
        }

        It 'Combined with actual orphan: detects items not in any file' {
            $orphanItem = [PSCustomObject]@{ id = '5'; name = 'beet'; pluralName = 'beets'; aliases = @() }
            $existingWithOrphan = $existingItems + @($orphanItem)
            $combinedItems = $file1Items + $file2Items

            $toDelete = @(Get-ItemsToDelete -ExistingItems $existingWithOrphan -ImportItems $combinedItems -MatchById)

            $toDelete.Count | Should -Be 1
            $toDelete[0].name | Should -Be 'beet'
        }
    }

    Context 'Matching by name and aliases' {
        It 'Matches by name when IDs differ' {
            $existing = @([PSCustomObject]@{ id = 'x'; name = 'tomato'; pluralName = 'tomatoes'; aliases = @() })
            $import = @([PSCustomObject]@{ id = 'y'; name = 'tomato'; pluralName = 'tomatoes'; aliases = @() })

            $toDelete = @(Get-ItemsToDelete -ExistingItems $existing -ImportItems $import -MatchById)

            $toDelete.Count | Should -Be 0
        }

        It 'Matches existing name against import alias' {
            $existing = @([PSCustomObject]@{ id = '1'; name = 'courgette'; pluralName = 'courgettes'; aliases = @() })
            $import = @([PSCustomObject]@{
                id = '2'; name = 'zucchini'; pluralName = 'zucchinis'
                aliases = @([PSCustomObject]@{ name = 'courgette' })
            })

            $toDelete = @(Get-ItemsToDelete -ExistingItems $existing -ImportItems $import -MatchById)

            $toDelete.Count | Should -Be 0
        }

        It 'Matches existing alias against import name' {
            $existing = @([PSCustomObject]@{
                id = '1'; name = 'zucchini'; pluralName = 'zucchinis'
                aliases = @([PSCustomObject]@{ name = 'courgette' })
            })
            $import = @([PSCustomObject]@{ id = '2'; name = 'courgette'; pluralName = 'courgettes'; aliases = @() })

            $toDelete = @(Get-ItemsToDelete -ExistingItems $existing -ImportItems $import -MatchById)

            $toDelete.Count | Should -Be 0
        }
    }

    Context 'Edge cases' {
        It 'Handles empty import items' {
            $existing = @([PSCustomObject]@{ id = '1'; name = 'tomato'; pluralName = ''; aliases = @() })
            $toDelete = @(Get-ItemsToDelete -ExistingItems $existing -ImportItems @() -MatchById)

            $toDelete.Count | Should -Be 1
        }

        It 'Handles empty existing items' {
            $import = @([PSCustomObject]@{ id = '1'; name = 'tomato'; pluralName = ''; aliases = @() })
            $toDelete = @(Get-ItemsToDelete -ExistingItems @() -ImportItems $import -MatchById)

            $toDelete.Count | Should -Be 0
        }

        It 'Handles null inputs' {
            $toDelete = @(Get-ItemsToDelete -ExistingItems $null -ImportItems $null -MatchById)

            $toDelete.Count | Should -Be 0
        }
    }
}

Describe 'Sync-MealieFoods -Folder' {
    Context 'WhatIf mode with mocked API' {
        BeforeAll {
            $script:existingFoods = @(
                [PSCustomObject]@{ id = '1'; name = 'tomato'; pluralName = 'tomatoes'; label = [PSCustomObject]@{ name = 'Vegetables' }; aliases = @() }
                [PSCustomObject]@{ id = '2'; name = 'potato'; pluralName = 'potatoes'; label = [PSCustomObject]@{ name = 'Tubers' }; aliases = @() }
                [PSCustomObject]@{ id = '99'; name = 'orphan-food'; pluralName = 'orphan-foods'; label = [PSCustomObject]@{ name = 'Vegetables' }; aliases = @() }
            )
        }

        BeforeEach {
            Mock -ModuleName MealieApi Get-MealieFoods { return $script:existingFoods }
            Mock -ModuleName MealieApi Invoke-MealieRequest { return @() }
            Mock Test-MealieFoodConflicts { return @{ HasConflicts = $false; ConflictCount = 0 } } -ParameterFilter { $Quiet }
            Mock -ModuleName MealieApi Import-MealieFoods { return @{
                Created = 0; Updated = 0; Unchanged = 1; Skipped = 0
                Errors = 0; LabelWarnings = 0; Conflicts = 0
            }}
        }

        It 'Uses combined items from all files for deletion calculation' {
            $testFolder = Join-Path $TestDrive 'foods'
            New-Item -Path $testFolder -ItemType Directory -Force | Out-Null

            $file1 = @{
                '$schema' = 'mealie-sync'; '$type' = 'Foods'; '$version' = '1.0'
                items = @(@{ id = '1'; name = 'tomato'; pluralName = 'tomatoes'; label = 'Vegetables'; aliases = @() })
            }
            $file2 = @{
                '$schema' = 'mealie-sync'; '$type' = 'Foods'; '$version' = '1.0'
                items = @(@{ id = '2'; name = 'potato'; pluralName = 'potatoes'; label = 'Tubers'; aliases = @() })
            }

            $file1 | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $testFolder 'vegetables.json')
            $file2 | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $testFolder 'tubers.json')

            $result = Sync-MealieFoods -Folder $testFolder -WhatIf -BasePath $TestDrive

            $result.Deleted | Should -Be 1 -Because 'only orphan-food is not in any file'
            $result.Deleted | Should -Not -Be 4 -Because 'the old bug would count 2 per file = 4'
        }

        It 'Returns zero deletions when all items are covered' {
            $testFolder = Join-Path $TestDrive 'foods-full'
            New-Item -Path $testFolder -ItemType Directory -Force | Out-Null

            Mock -ModuleName MealieApi Get-MealieFoods { return @(
                [PSCustomObject]@{ id = '1'; name = 'tomato'; pluralName = ''; aliases = @() }
                [PSCustomObject]@{ id = '2'; name = 'potato'; pluralName = ''; aliases = @() }
            )}

            $file1 = @{
                '$schema' = 'mealie-sync'; '$type' = 'Foods'; '$version' = '1.0'
                items = @(@{ id = '1'; name = 'tomato'; pluralName = ''; aliases = @() })
            }
            $file2 = @{
                '$schema' = 'mealie-sync'; '$type' = 'Foods'; '$version' = '1.0'
                items = @(@{ id = '2'; name = 'potato'; pluralName = ''; aliases = @() })
            }

            $file1 | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $testFolder 'veg.json')
            $file2 | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $testFolder 'tubers.json')

            $result = Sync-MealieFoods -Folder $testFolder -WhatIf -BasePath $TestDrive

            $result.Deleted | Should -Be 0
        }
    }
}

Describe 'Sync-MealieUnits -Folder' {
    Context 'WhatIf mode with mocked API' {
        BeforeEach {
            Mock -ModuleName MealieApi Get-MealieUnits { return @(
                [PSCustomObject]@{ id = '1'; name = 'gram'; pluralName = 'gram'; aliases = @() }
                [PSCustomObject]@{ id = '2'; name = 'liter'; pluralName = 'liter'; aliases = @() }
                [PSCustomObject]@{ id = '99'; name = 'orphan-unit'; pluralName = 'orphan-units'; aliases = @() }
            )}
            Mock -ModuleName MealieApi Invoke-MealieRequest { return @() }
            Mock Test-MealieUnitConflicts { return @{ HasConflicts = $false; ConflictCount = 0 } } -ParameterFilter { $Quiet }
            Mock -ModuleName MealieApi Import-MealieUnits { return @{
                Created = 0; Updated = 0; Unchanged = 1; Skipped = 0
                Errors = 0; Conflicts = 0
            }}
        }

        It 'Uses combined items from all files for deletion calculation' {
            $testFolder = Join-Path $TestDrive 'units'
            New-Item -Path $testFolder -ItemType Directory -Force | Out-Null

            $file1 = @{
                '$schema' = 'mealie-sync'; '$type' = 'Units'; '$version' = '1.0'
                items = @(@{ id = '1'; name = 'gram'; pluralName = 'gram'; aliases = @() })
            }
            $file2 = @{
                '$schema' = 'mealie-sync'; '$type' = 'Units'; '$version' = '1.0'
                items = @(@{ id = '2'; name = 'liter'; pluralName = 'liter'; aliases = @() })
            }

            $file1 | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $testFolder 'weight.json')
            $file2 | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $testFolder 'volume.json')

            $result = Sync-MealieUnits -Folder $testFolder -WhatIf -BasePath $TestDrive

            $result.Deleted | Should -Be 1 -Because 'only orphan-unit is not in any file'
        }
    }
}
