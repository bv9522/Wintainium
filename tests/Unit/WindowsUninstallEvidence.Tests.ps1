BeforeAll {
    $testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

    Import-Module $modulePath -Force

    function New-TestWindowsRegistryReader {
        param(
            [Parameter(Mandatory)]
            [hashtable]$EntriesByLocation
        )

        return {
            param($location)
            $key = '{0}/{1}' -f $location.scope, $location.view
            if ($EntriesByLocation.ContainsKey($key)) {
                return @($EntriesByLocation[$key])
            }
            return @()
        }.GetNewClosure()
    }

    function New-TestWindowsSettings {
        param(
            [object[]]$Locations = @(
                [pscustomobject]@{ scope = 'machine'; view = '64' }
            ),
            [object[]]$Match = @(
                [pscustomobject]@{ value = 'DisplayName'; equals = 'Example Application' }
            )
        )

        [pscustomobject]@{
            registry = [pscustomobject]@{
                locations = $Locations
                match = $Match
            }
        }
    }
}

Describe 'Windows uninstall registry evidence reader' {
    It 'enumerates deterministic candidates from machine 64-bit data' {
        $settings = New-TestWindowsSettings
        $entries = @{
            'machine/64' = @(
                [pscustomobject]@{
                    Scope = 'machine'; View = '64'; SubKey = 'Example';
                    DisplayName = 'Example Application'; DisplayVersion = '1.2.3';
                    Publisher = 'Example Publisher'; InstallLocation = 'C:\Program Files\Example'
                }
            )
        }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Settings = $settings
            Reader = (New-TestWindowsRegistryReader -EntriesByLocation $entries)
        } {
            Get-WintainiumWindowsUninstallCandidates -Settings $Settings -RegistryReader $Reader
        }

        $result.IsSuccessful | Should -BeTrue
        @($result.Candidates).Count | Should -Be 1
        $result.Candidates[0].SubKey | Should -Be 'Example'
        $result.Candidates[0].DisplayVersion | Should -Be '1.2.3'
        $result.Candidates[0].InstallLocation | Should -Be 'C:\Program Files\Example'
        $result.Candidates[0].EvidenceSource | Should -Be 'WindowsUninstallRegistry'
    }

    It 'supports machine 32-bit and current-user locations without conflating architecture' {
        $settings = New-TestWindowsSettings -Locations @(
            [pscustomobject]@{ scope = 'machine'; view = '32' }
            [pscustomobject]@{ scope = 'user'; view = 'native' }
        )
        $entries = @{
            'machine/32' = @(
                [pscustomobject]@{
                    Scope = 'machine'; View = '32'; SubKey = 'Example32';
                    DisplayName = 'Example Application'; DisplayVersion = '2.0'; Publisher = 'Publisher'; InstallLocation = $null
                }
            )
            'user/native' = @(
                [pscustomobject]@{
                    Scope = 'user'; View = 'native'; SubKey = 'ExampleUser';
                    DisplayName = 'Different Application'; DisplayVersion = '3.0'; Publisher = 'Publisher'; InstallLocation = $null
                }
            )
        }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Settings = $settings
            Reader = (New-TestWindowsRegistryReader -EntriesByLocation $entries)
        } {
            Get-WintainiumWindowsUninstallCandidates -Settings $Settings -RegistryReader $Reader
        }

        $result.IsSuccessful | Should -BeTrue
        @($result.Candidates).Count | Should -Be 1
        $result.Candidates[0].View | Should -Be '32'
        $result.Candidates[0].PSObject.Properties.Name | Should -Not -Contain 'Architecture'
    }

    It 'requires exact case-insensitive matching rather than substring matching' {
        $settings = New-TestWindowsSettings -Match @(
            [pscustomobject]@{ value = 'DisplayName'; equals = 'example application' }
        )
        $entries = @{
            'machine/64' = @(
                [pscustomobject]@{ Scope = 'machine'; View = '64'; SubKey = 'Exact'; DisplayName = 'EXAMPLE APPLICATION'; DisplayVersion = '1'; Publisher = 'P' }
                [pscustomobject]@{ Scope = 'machine'; View = '64'; SubKey = 'Partial'; DisplayName = 'Example Application Plus'; DisplayVersion = '2'; Publisher = 'P' }
            )
        }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Settings = $settings
            Reader = (New-TestWindowsRegistryReader -EntriesByLocation $entries)
        } {
            Get-WintainiumWindowsUninstallCandidates -Settings $Settings -RegistryReader $Reader
        }

        $result.IsSuccessful | Should -BeTrue
        @($result.Candidates).Count | Should -Be 1
        $result.Candidates[0].SubKey | Should -Be 'Exact'
    }

    It 'requires every declared predicate to match' {
        $settings = New-TestWindowsSettings -Match @(
            [pscustomobject]@{ value = 'DisplayName'; equals = 'Example Application' }
            [pscustomobject]@{ value = 'Publisher'; equals = 'Example Publisher' }
        )
        $entries = @{
            'machine/64' = @(
                [pscustomobject]@{ Scope = 'machine'; View = '64'; SubKey = 'WrongPublisher'; DisplayName = 'Example Application'; DisplayVersion = '1'; Publisher = 'Other' }
                [pscustomobject]@{ Scope = 'machine'; View = '64'; SubKey = 'Match'; DisplayName = 'Example Application'; DisplayVersion = '2'; Publisher = 'Example Publisher' }
            )
        }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Settings = $settings
            Reader = (New-TestWindowsRegistryReader -EntriesByLocation $entries)
        } {
            Get-WintainiumWindowsUninstallCandidates -Settings $Settings -RegistryReader $Reader
        }

        @($result.Candidates).Count | Should -Be 1
        $result.Candidates[0].SubKey | Should -Be 'Match'
    }

    It 'returns multiple candidates without resolving ambiguity' {
        $settings = New-TestWindowsSettings
        $entries = @{
            'machine/64' = @(
                [pscustomobject]@{ Scope = 'machine'; View = '64'; SubKey = 'One'; DisplayName = 'Example Application'; DisplayVersion = '1'; Publisher = 'P' }
                [pscustomobject]@{ Scope = 'machine'; View = '64'; SubKey = 'Two'; DisplayName = 'Example Application'; DisplayVersion = '2'; Publisher = 'P' }
            )
        }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Settings = $settings
            Reader = (New-TestWindowsRegistryReader -EntriesByLocation $entries)
        } {
            Get-WintainiumWindowsUninstallCandidates -Settings $Settings -RegistryReader $Reader
        }

        $result.IsSuccessful | Should -BeTrue
        @($result.Candidates).Count | Should -Be 2
        @($result.Candidates.SubKey) | Should -Contain 'One'
        @($result.Candidates.SubKey) | Should -Contain 'Two'
    }

    It 'returns no candidates when the search completes without a match' {
        $settings = New-TestWindowsSettings
        $entries = @{
            'machine/64' = @(
                [pscustomobject]@{ Scope = 'machine'; View = '64'; SubKey = 'Other'; DisplayName = 'Other Application'; DisplayVersion = '1'; Publisher = 'P' }
            )
        }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Settings = $settings
            Reader = (New-TestWindowsRegistryReader -EntriesByLocation $entries)
        } {
            Get-WintainiumWindowsUninstallCandidates -Settings $Settings -RegistryReader $Reader
        }

        $result.IsSuccessful | Should -BeTrue
        @($result.Candidates).Count | Should -Be 0
    }

    It 'reports a registry read failure instead of turning it into not installed' {
        $settings = New-TestWindowsSettings
        $reader = {
            param($location)
            throw 'synthetic registry access failure'
        }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Settings = $settings
            Reader = $reader
        } {
            Get-WintainiumWindowsUninstallCandidates -Settings $Settings -RegistryReader $Reader
        }

        $result.IsSuccessful | Should -BeFalse
        @($result.Candidates).Count | Should -Be 0
        @($result.Errors.Code) | Should -Contain 'WindowsRegistryLocationReadFailed'
    }

    It 'reports malformed scalar expectations without manufacturing a candidate' {
        $settings = New-TestWindowsSettings
        $entries = @{
            'machine/64' = @(
                [pscustomobject]@{
                    Scope = 'machine'; View = '64'; SubKey = 'Malformed';
                    DisplayName = @('Example Application', 'Unexpected Second Value');
                    DisplayVersion = '1'; Publisher = 'P'
                }
            )
        }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Settings = $settings
            Reader = (New-TestWindowsRegistryReader -EntriesByLocation $entries)
        } {
            Get-WintainiumWindowsUninstallCandidates -Settings $Settings -RegistryReader $Reader
        }

        $result.IsSuccessful | Should -BeFalse
        @($result.Candidates).Count | Should -Be 0
        @($result.Errors.Code) | Should -Contain 'WindowsRegistryValueMalformed'
    }

    It 'rejects arbitrary registry scopes and views' {
        $settings = New-TestWindowsSettings -Locations @(
            [pscustomobject]@{ scope = 'machine'; view = 'native' }
        )

        {
            InModuleScope Wintainium.Core -Parameters @{ Settings = $settings } {
                Get-WintainiumWindowsUninstallCandidates -Settings $Settings -RegistryReader { param($location) @() }
            }
        } | Should -Throw '*requires view*'
    }

    It 'supports subkey identity without depending on a display name' {
        $settings = New-TestWindowsSettings -Match @(
            [pscustomobject]@{ value = 'subkey'; equals = '{PRODUCT-CODE}' }
        )
        $entries = @{
            'machine/64' = @(
                [pscustomobject]@{ Scope = 'machine'; View = '64'; SubKey = '{PRODUCT-CODE}'; DisplayName = $null; DisplayVersion = '4.5'; Publisher = 'Vendor' }
            )
        }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Settings = $settings
            Reader = (New-TestWindowsRegistryReader -EntriesByLocation $entries)
        } {
            Get-WintainiumWindowsUninstallCandidates -Settings $Settings -RegistryReader $Reader
        }

        $result.IsSuccessful | Should -BeTrue
        @($result.Candidates).Count | Should -Be 1
        $result.Candidates[0].SubKey | Should -Be '{PRODUCT-CODE}'
    }
}
