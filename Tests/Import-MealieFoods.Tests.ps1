#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'MealieApi.psm1'
    Import-Module $modulePath -Force
}

Describe 'Import-MealieFoods id fallback' {
    BeforeAll {
        $importFile = Join-Path $TestDrive 'Foods.json'
        @{
            '$schema'  = 'mealie-sync'
            '$type'    = 'Foods'
            '$version' = '1.0'
            items      = @(
                @{ id = '3df97b13-110a-409f-9d8f-5aaa5a72f185'; name = 'truffelmayonaise'
                    pluralName = 'truffelmayonaise'; description = 'Mayonaise met truffel; op hapjes.'
                    aliases = @(); label = 'Sauzen & Condimenten' }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $importFile -Encoding utf8
    }

    # Food ids are unique across the whole instance, so a dataset id another group already holds is
    # refused. Older Mealie answered 400, current Mealie answers 409; both must fall back to no id.
    It 'retries without the id when the server refuses it with <Status>' -ForEach @(
        @{ Status = 400 }
        @{ Status = 409 }
    ) {
        InModuleScope MealieApi -Parameters @{ File = $importFile; Status = $Status } {
            param($File, $Status)
            Mock Get-MealieFoods { , @() }
            Mock Get-MealieLabels { @([PSCustomObject]@{ id = 'label-1'; name = 'Sauzen & Condimenten' }) }
            Mock New-MealieFood {
                if ($Id) { throw "API Error ($Status): This item already exists." }
            }

            $result = Import-MealieFoods -Path $File -SkipBackup -SkipConflictCheck -ThrottleMs 0 -Quiet

            $result.Created | Should -Be 1
            $result.Errors | Should -Be 0
            Should -Invoke New-MealieFood -Times 1 -Exactly -ParameterFilter { $Id }
            Should -Invoke New-MealieFood -Times 1 -Exactly -ParameterFilter { -not $Id }
        }
    }

    It 'does not retry on an unrelated error' {
        InModuleScope MealieApi -Parameters @{ File = $importFile } {
            param($File)
            Mock Get-MealieFoods { , @() }
            Mock Get-MealieLabels { , @() }
            Mock New-MealieFood { throw 'API Error (500): Internal Server Error' }

            $result = Import-MealieFoods -Path $File -SkipBackup -SkipConflictCheck -ThrottleMs 0 -Quiet

            $result.Errors | Should -Be 1
            Should -Invoke New-MealieFood -Times 1 -Exactly
        }
    }
}
