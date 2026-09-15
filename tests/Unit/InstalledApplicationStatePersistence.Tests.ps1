$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

Import-Module $modulePath -Force

Describe 'Wintainium installed application state persistence' {
    BeforeEach {
        $stateRoot = Join-Path $TestDrive 'state'
    }

    It 'returns Unknown when no persisted state exists' {
        $state = InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot } {
            param($StateRoot)
            Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId 'org.example.app'
        }

        $state.InstallationState | Should -Be 'Unknown'
        $state.ApplicationId | Should -Be 'org.example.app'
    }

    It 'persists and retrieves all installed-state observations' {
        $state = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Installed -Version '1.2.vendor-build' -VersionSource Registry -Architecture x64 -Channel stable -InstallationLocation 'C:\Program Files\Example'
        }

        InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot; State = $state } {
            param($StateRoot, $State)
            Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $State | Out-Null
        }

        $loaded = InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot } {
            param($StateRoot)
            Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId 'org.example.app'
        }

        $loaded | Should -Not -BeNullOrEmpty
        $loaded.ApplicationId | Should -Be 'org.example.app'
        $loaded.InstallationState | Should -Be 'Installed'
        $loaded.Version | Should -Be '1.2.vendor-build'
        $loaded.VersionSource | Should -Be 'Registry'
        $loaded.Architecture | Should -Be 'x64'
        $loaded.Channel | Should -Be 'stable'
        $loaded.InstallationLocation | Should -Be 'C:\Program Files\Example'
    }

    It 'keeps separate application records in one state store' {
        foreach ($id in @('org.example.one', 'org.example.two')) {
            $state = InModuleScope Wintainium.Core -Parameters @{ ApplicationId = $id } {
                param($ApplicationId)
                New-WintainiumInstalledApplicationState -ApplicationId $ApplicationId -InstallationState Installed -Version '1.0'
            }

            InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot; State = $state } {
                param($StateRoot, $State)
                Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $State | Out-Null
            }
        }

        $one = InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot } {
            param($StateRoot)
            Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId 'org.example.one'
        }
        $two = InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot } {
            param($StateRoot)
            Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId 'org.example.two'
        }

        $one.ApplicationId | Should -Be 'org.example.one'
        $two.ApplicationId | Should -Be 'org.example.two'
    }

    It 'replaces an existing application record rather than creating duplicates' {
        foreach ($version in @('1.0', '2.0')) {
            $state = InModuleScope Wintainium.Core -Parameters @{ Version = $version } {
                param($Version)
                New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Installed -Version $Version
            }

            InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot; State = $state } {
                param($StateRoot, $State)
                Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $State | Out-Null
            }
        }

        $document = Get-Content -LiteralPath (Join-Path $stateRoot 'installed-state.json') -Raw | ConvertFrom-Json
        @($document.States | Where-Object ApplicationId -eq 'org.example.app').Count | Should -Be 1
        @($document.States | Where-Object ApplicationId -eq 'org.example.app')[0].Version | Should -Be '2.0'
    }

    It 'persists NotInstalled without inventing a version' {
        $state = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState NotInstalled
        }

        InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot; State = $state } {
            param($StateRoot, $State)
            Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $State | Out-Null
        }

        $loaded = InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot } {
            param($StateRoot)
            Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId 'org.example.app'
        }

        $loaded.InstallationState | Should -Be 'NotInstalled'
        $loaded.Version | Should -BeNullOrEmpty
    }

    It 'preserves Unknown instead of guessing installation state' {
        $state = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Unknown
        }

        InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot; State = $state } {
            param($StateRoot, $State)
            Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $State | Out-Null
        }

        $loaded = InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot } {
            param($StateRoot)
            Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId 'org.example.app'
        }

        $loaded.InstallationState | Should -Be 'Unknown'
    }

    It 'rejects invalid state before writing' {
        $state = [pscustomobject][ordered]@{
            ApplicationId = ''
            InstallationState = 'Installed'
            Version = '1.0'
            VersionSource = 'Registry'
            Architecture = 'x64'
            Channel = 'stable'
            InstallationLocation = $null
        }

        {
            InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot; State = $state } {
                param($StateRoot, $State)
                Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $State
            }
        } | Should -Throw

        Test-Path -LiteralPath (Join-Path $stateRoot 'installed-state.json') | Should -BeFalse
    }

    It 'rejects an unsupported persisted schema version' {
        New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
        @{ SchemaVersion = 99; States = @() } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stateRoot 'installed-state.json')

        {
            InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot } {
                param($StateRoot)
                Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId 'org.example.app'
            }
        } | Should -Throw
    }

    It 'rejects malformed persisted state instead of guessing' {
        New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
        '{ invalid json' | Set-Content -LiteralPath (Join-Path $stateRoot 'installed-state.json')

        {
            InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot } {
                param($StateRoot)
                Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId 'org.example.app'
            }
        } | Should -Throw
    }

    It 'writes a valid JSON state document with schema version 1' {
        $state = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Installed -Version '1.0'
        }

        InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot; State = $state } {
            param($StateRoot, $State)
            Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $State | Out-Null
        }

        $document = Get-Content -LiteralPath (Join-Path $stateRoot 'installed-state.json') -Raw | ConvertFrom-Json
        $document.SchemaVersion | Should -Be 1
        @($document.States).Count | Should -Be 1
    }
}
