$modulePath = Join-Path $PSScriptRoot '..' '..' 'core' 'Wintainium.Core' 'Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium update decision input' {
    It 'assembles validated manifest, installed state, and provider result' {
        $manifest = [pscustomobject]@{ Id = 'Example.App' }
        $installedState = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'Example.App' -InstallationState 'Installed' -Version '1.2.3' -VersionSource 'test'
        }
        $providerResult = [pscustomobject]@{ IsSuccessful = $true; Releases = @() }

        $input = InModuleScope Wintainium.Core -Parameters @{ Manifest = $manifest; InstalledState = $installedState; ProviderResult = $providerResult } {
            param($Manifest, $InstalledState, $ProviderResult)
            New-WintainiumUpdateDecisionInput -Manifest $Manifest -InstalledState $InstalledState -ProviderResult $ProviderResult
        }

        $input.Manifest | Should -Be $manifest
        $input.InstalledState | Should -Be $installedState
        $input.ProviderResult | Should -Be $providerResult
    }

    It 'requires the manifest identity to match installed state identity' {
        $manifest = [pscustomobject]@{ Id = 'Example.Other' }
        $installedState = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'Example.App' -InstallationState 'Installed' -Version '1.2.3' -VersionSource 'test'
        }
        $providerResult = [pscustomobject]@{ IsSuccessful = $true; Releases = @() }

        {
            InModuleScope Wintainium.Core -Parameters @{ Manifest = $manifest; InstalledState = $installedState; ProviderResult = $providerResult } {
                param($Manifest, $InstalledState, $ProviderResult)
                New-WintainiumUpdateDecisionInput -Manifest $Manifest -InstalledState $InstalledState -ProviderResult $ProviderResult
            }
        } | Should -Throw '*Manifest.Id must match InstalledState.ApplicationId*'
    }

    It 'rejects an invalid installed state' {
        $manifest = [pscustomobject]@{ Id = 'Example.App' }
        $invalidState = [pscustomobject]@{
            ApplicationId = 'Example.App'
            InstallationState = 'Invalid'
            Version = '1.2.3'
            VersionSource = 'test'
            Architecture = 'unknown'
            Channel = 'unknown'
            InstallationLocation = $null
        }
        $providerResult = [pscustomobject]@{ IsSuccessful = $true; Releases = @() }

        {
            InModuleScope Wintainium.Core -Parameters @{ Manifest = $manifest; InstalledState = $invalidState; ProviderResult = $providerResult } {
                param($Manifest, $InstalledState, $ProviderResult)
                New-WintainiumUpdateDecisionInput -Manifest $Manifest -InstalledState $InstalledState -ProviderResult $ProviderResult
            }
        } | Should -Throw '*InstalledState must be a valid*'
    }

    It 'does not mutate input objects' {
        $manifest = [pscustomobject]@{ Id = 'Example.App'; Name = 'Example' }
        $installedState = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'Example.App' -InstallationState 'Installed' -Version '1.2.3' -VersionSource 'test'
        }
        $providerResult = [pscustomobject]@{ IsSuccessful = $true; Releases = @() }
        $manifestBefore = $manifest | ConvertTo-Json -Depth 10
        $stateBefore = $installedState | ConvertTo-Json -Depth 10
        $providerBefore = $providerResult | ConvertTo-Json -Depth 10

        InModuleScope Wintainium.Core -Parameters @{ Manifest = $manifest; InstalledState = $installedState; ProviderResult = $providerResult } {
            param($Manifest, $InstalledState, $ProviderResult)
            New-WintainiumUpdateDecisionInput -Manifest $Manifest -InstalledState $InstalledState -ProviderResult $ProviderResult | Out-Null
        }

        ($manifest | ConvertTo-Json -Depth 10) | Should -Be $manifestBefore
        ($installedState | ConvertTo-Json -Depth 10) | Should -Be $stateBefore
        ($providerResult | ConvertTo-Json -Depth 10) | Should -Be $providerBefore
    }

    It 'does not require provider access or network activity during construction' {
        $manifest = [pscustomobject]@{ Id = 'Example.App' }
        $installedState = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'Example.App' -InstallationState 'Installed' -Version '1.2.3' -VersionSource 'test'
        }
        $providerResult = [pscustomobject]@{ IsSuccessful = $true; Releases = @() }

        { InModuleScope Wintainium.Core -Parameters @{ Manifest = $manifest; InstalledState = $installedState; ProviderResult = $providerResult } {
                param($Manifest, $InstalledState, $ProviderResult)
                New-WintainiumUpdateDecisionInput -Manifest $Manifest -InstalledState $InstalledState -ProviderResult $ProviderResult | Out-Null
            }
        } | Should -Not -Throw
    }
}
