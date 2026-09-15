$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium application update decision composition' {
    BeforeAll {
        $manifest = [pscustomobject]@{
            Id = 'example.app'
            Release = [pscustomobject]@{ channel = 'stable' }
            artifact = [pscustomobject]@{
                formats = @('msi')
                architectures = @('x64','neutral')
                allowUnknownArchitecture = $false
            }
        }
        $successfulRelease = [pscustomobject]@{
            OperationId = 'release-operation'
            IsSuccessful = $true
            Status = 'DiscoveryCompleted'
            Manifest = $manifest
            Errors = @()
            Warnings = @()
            LogEvents = @()
            Releases = @([pscustomobject]@{
                ReleaseId = 'release-2'
                Version = '2.0.0'
                Channel = 'stable'
                Deprecated = $false
                Artifacts = @([pscustomobject]@{
                    Uri = 'https://example.test/app.msi'
                    Format = 'msi'
                    Architecture = 'x64'
                })
            })
        }
    }

    It 'composes persisted installed state into the Phase 4 decision without exposing internal inputs to the caller' {
        $stateRoot = Join-Path $TestDrive 'state'
        InModuleScope Wintainium.Core -Parameters @{ Manifest=$manifest; Release=$successfulRelease; StateRoot=$stateRoot } {
            param($Manifest,$Release,$StateRoot)
            Mock Get-WintainiumApplicationRelease { $Release }
            Mock Get-WintainiumInstalledApplicationState {
                New-WintainiumInstalledApplicationState -ApplicationId $Manifest.Id -InstallationState Installed -Version '1.0.0' -VersionSource 'Wintainium' -Architecture x64 -Channel stable
            }
            $result = Get-WintainiumApplicationUpdateDecision -ManifestPath 'C:\example.manifest.json' -StateRoot $StateRoot -MachineArchitecture x64
            $result.OperationId | Should -Be 'release-operation'
            $result.IsSuccessful | Should -BeTrue
            $result.Status | Should -Be 'UpdateAvailable'
            $result.InstalledState.ApplicationId | Should -Be 'example.app'
            $result.InstalledState.Version | Should -Be '1.0.0'
            $result.Decision.SelectedRelease.ReleaseId | Should -Be 'release-2'
            Should -Invoke Get-WintainiumApplicationRelease -Times 1 -Exactly
            Should -Invoke Get-WintainiumInstalledApplicationState -Times 1 -Exactly
        }
    }

    It 'preserves Unknown installed state as an indeterminate Phase 4 decision' {
        $stateRoot = Join-Path $TestDrive 'unknown-state'
        InModuleScope Wintainium.Core -Parameters @{ Release=$successfulRelease; StateRoot=$stateRoot } {
            param($Release,$StateRoot)
            Mock Get-WintainiumApplicationRelease { $Release }
            Mock Get-WintainiumInstalledApplicationState {
                New-WintainiumInstalledApplicationState -ApplicationId 'example.app' -InstallationState Unknown
            }
            $result = Get-WintainiumApplicationUpdateDecision -ManifestPath 'C:\example.manifest.json' -StateRoot $StateRoot -MachineArchitecture x64
            $result.Status | Should -Be 'DecisionIndeterminate'
            $result.Decision.ReasonCode | Should -Be 'InstalledStateUnknown'
            $result.Decision.IsUpdateAvailable | Should -BeNullOrEmpty
        }
    }

    It 'preserves NotInstalled state without treating the latest release as an update' {
        $stateRoot = Join-Path $TestDrive 'not-installed'
        InModuleScope Wintainium.Core -Parameters @{ Release=$successfulRelease; StateRoot=$stateRoot } {
            param($Release,$StateRoot)
            Mock Get-WintainiumApplicationRelease { $Release }
            Mock Get-WintainiumInstalledApplicationState {
                New-WintainiumInstalledApplicationState -ApplicationId 'example.app' -InstallationState NotInstalled
            }
            $result = Get-WintainiumApplicationUpdateDecision -ManifestPath 'C:\example.manifest.json' -StateRoot $StateRoot -MachineArchitecture x64
            $result.Status | Should -Be 'ApplicationNotInstalled'
            $result.Decision.IsUpdateAvailable | Should -BeFalse
        }
    }

    It 'does not continue to decision processing when release discovery fails' {
        $stateRoot = Join-Path $TestDrive 'release-failure'
        $failedRelease = [pscustomobject]@{
            OperationId = 'failed-operation'
            IsSuccessful = $false
            Status = 'ProviderDiscoveryFailed'
            Manifest = $null
            Errors = @([pscustomobject]@{ Code='ProviderFailure'; Message='Provider failed.' })
            Warnings = @()
            LogEvents = @()
            Releases = @()
        }
        InModuleScope Wintainium.Core -Parameters @{ Release=$failedRelease; StateRoot=$stateRoot } {
            param($Release,$StateRoot)
            Mock Get-WintainiumApplicationRelease { $Release }
            Mock Get-WintainiumInstalledApplicationState { throw 'State source must not run after release discovery failure.' }
            $result = Get-WintainiumApplicationUpdateDecision -ManifestPath 'C:\example.manifest.json' -StateRoot $StateRoot -MachineArchitecture x64
            $result.IsSuccessful | Should -BeFalse
            $result.Status | Should -Be 'ProviderDiscoveryUnsuccessful'
            $result.Errors[0].Code | Should -Be 'ProviderFailure'
            Should -Invoke Get-WintainiumInstalledApplicationState -Times 0
        }
    }

    It 'keeps the Core-generated operation identifier from release discovery' {
        $stateRoot = Join-Path $TestDrive 'operation-id'
        InModuleScope Wintainium.Core -Parameters @{ Manifest=$manifest; Release=$successfulRelease; StateRoot=$stateRoot } {
            param($Manifest,$Release,$StateRoot)
            Mock Get-WintainiumApplicationRelease { $Release }
            Mock Get-WintainiumInstalledApplicationState {
                New-WintainiumInstalledApplicationState -ApplicationId $Manifest.Id -InstallationState Installed -Version '1.0.0' -Architecture x64 -Channel stable
            }
            $result = Get-WintainiumApplicationUpdateDecision -ManifestPath 'C:\example.manifest.json' -StateRoot $StateRoot -MachineArchitecture x64
            $result.OperationId | Should -Be $Release.OperationId
        }
    }

    It 'rejects an empty state root before beginning composition' {
        InModuleScope Wintainium.Core {
            { Get-WintainiumApplicationUpdateDecision -ManifestPath 'C:\example.manifest.json' -StateRoot '   ' -MachineArchitecture x64 } |
                Should -Throw '*StateRoot must not be empty or whitespace*'
        }
    }
}
