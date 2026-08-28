$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

Import-Module $modulePath -Force

Describe 'Wintainium installed application state' {
    It 'creates a valid installed state with all observations preserved' {
        $state = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Installed -Version '1.2.vendor-build' -VersionSource Registry -Architecture x64 -Channel stable -InstallationLocation 'C:\Program Files\Example'
        }

        $state.ApplicationId | Should -Be 'org.example.app'
        $state.InstallationState | Should -Be 'Installed'
        $state.Version | Should -Be '1.2.vendor-build'
        $state.VersionSource | Should -Be 'Registry'
        $state.Architecture | Should -Be 'x64'
        $state.Channel | Should -Be 'stable'
        $state.InstallationLocation | Should -Be 'C:\Program Files\Example'
    }

    It 'allows an installed application to have unknown optional observations' {
        $state = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Installed -Version '1.0' -VersionSource Unknown
        }

        $state.Architecture | Should -Be 'unknown'
        $state.Channel | Should -Be 'unknown'
        $state.InstallationLocation | Should -BeNullOrEmpty
    }

    It 'creates a valid not-installed state without a version' {
        $state = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState NotInstalled
        }

        $state.InstallationState | Should -Be 'NotInstalled'
        $state.Version | Should -BeNullOrEmpty
    }

    It 'creates a valid unknown installation state' {
        $state = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Unknown
        }

        $state.InstallationState | Should -Be 'Unknown'
    }

    It 'preserves opaque vendor-specific version strings without comparison' {
        $state = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Installed -Version 'release-2026.08-r17' -VersionSource Installer
        }

        $state.Version | Should -Be 'release-2026.08-r17'
    }

    It 'rejects an empty application identifier' {
        {
            InModuleScope Wintainium.Core {
                New-WintainiumInstalledApplicationState -ApplicationId '   ' -InstallationState Installed
            }
        } | Should -Throw
    }

    It 'rejects an invalid installation state' {
        {
            InModuleScope Wintainium.Core {
                New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Invalid
            }
        } | Should -Throw
    }

    It 'rejects an invalid architecture' {
        {
            InModuleScope Wintainium.Core {
                New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Installed -Architecture ia64
            }
        } | Should -Throw
    }

    It 'rejects an invalid channel' {
        {
            InModuleScope Wintainium.Core {
                New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Installed -Channel beta
            }
        } | Should -Throw
    }

    It 'reports structured validation errors for a missing application identifier' {
        $state = [pscustomobject][ordered]@{
            ApplicationId = ''
            InstallationState = 'Installed'
            Version = '1.2.vendor-build'
            VersionSource = 'Registry'
            Architecture = 'x64'
            Channel = 'stable'
            InstallationLocation = 'C:\Program Files\Example'
        }
        $result = InModuleScope Wintainium.Core -Parameters @{ State = $state } {
            param($State)
            Test-WintainiumInstalledApplicationState -State $State
        }

        $result.IsValid | Should -BeFalse
        @($result.Errors).Count | Should -BeGreaterThan 0
        @($result.Errors | Where-Object Code -eq 'InstalledStateApplicationIdInvalid').Count | Should -Be 1
    }

    It 'reports structured validation errors when a not-installed state contains a version' {
        $state = [pscustomobject][ordered]@{
            ApplicationId = 'org.example.app'
            InstallationState = 'NotInstalled'
            Version = '1.0'
            VersionSource = 'Registry'
            Architecture = 'x64'
            Channel = 'stable'
            InstallationLocation = 'C:\Program Files\Example'
        }
        $result = InModuleScope Wintainium.Core -Parameters @{ State = $state } {
            param($State)
            Test-WintainiumInstalledApplicationState -State $State
        }

        $result.IsValid | Should -BeFalse
        @($result.Errors | Where-Object Code -eq 'InstalledStateVersionPresentWhenNotInstalled').Count | Should -Be 1
    }

    It 'accepts all defined architecture values' {
        foreach ($architecture in @('x86', 'x64', 'arm64', 'neutral', 'unknown')) {
            $state = [pscustomobject][ordered]@{
                ApplicationId = 'org.example.app'
                InstallationState = 'Installed'
                Version = '1.2.vendor-build'
                VersionSource = 'Registry'
                Architecture = $architecture
                Channel = 'stable'
                InstallationLocation = 'C:\Program Files\Example'
            }
            $result = InModuleScope Wintainium.Core -Parameters @{ State = $state } {
                param($State)
                Test-WintainiumInstalledApplicationState -State $State
            }

            $result.IsValid | Should -BeTrue
        }
    }

    It 'accepts all defined channel values' {
        foreach ($channel in @('stable', 'prerelease', 'unknown')) {
            $state = [pscustomobject][ordered]@{
                ApplicationId = 'org.example.app'
                InstallationState = 'Installed'
                Version = '1.2.vendor-build'
                VersionSource = 'Registry'
                Architecture = 'x64'
                Channel = $channel
                InstallationLocation = 'C:\Program Files\Example'
            }
            $result = InModuleScope Wintainium.Core -Parameters @{ State = $state } {
                param($State)
                Test-WintainiumInstalledApplicationState -State $State
            }

            $result.IsValid | Should -BeTrue
        }
    }
}
