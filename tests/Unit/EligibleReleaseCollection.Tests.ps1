$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium eligible release collection' {
    It 'returns eligible releases while preserving input order' {
        $releases=@(
            [pscustomobject]@{ ReleaseId='release-1.0.0'; Version='1.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@() },
            [pscustomobject]@{ ReleaseId='release-3.0.0'; Version='3.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@() },
            [pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@() }
        )
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='stable' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Releases=$releases; Manifest=$manifest; InstalledState=$installedState } { param($Releases,$Manifest,$InstalledState) Get-WintainiumEligibleRelease -Releases $Releases -Manifest $Manifest -InstalledState $InstalledState }
        @($result.EligibleReleases).Count | Should -Be 2
        $result.EligibleReleases[0].Version | Should -Be '3.0.0'
        $result.EligibleReleases[1].Version | Should -Be '2.0.0'
        $result.IsDeterministic | Should -BeTrue
    }

    It 'retains rejection observations for excluded releases' {
        $releases=@(
            [pscustomobject]@{ ReleaseId='release-1.0.0'; Version='1.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@() },
            [pscustomobject]@{ ReleaseId='release-2.0.0-prerelease'; Version='2.0.0'; Channel='prerelease'; Deprecated=$false; Artifacts=@() }
        )
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='stable' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Releases=$releases; Manifest=$manifest; InstalledState=$installedState } { param($Releases,$Manifest,$InstalledState) Get-WintainiumEligibleRelease -Releases $Releases -Manifest $Manifest -InstalledState $InstalledState }
        @($result.EligibleReleases).Count | Should -Be 0
        @($result.Observations).Count | Should -Be 2
        $result.Observations[0].ReasonCode | Should -Be 'NotNewer'
        $result.Observations[1].ReasonCode | Should -Be 'ChannelNotPermitted'
    }

    It 'handles an empty release set deterministically' {
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='stable' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Releases=@(); Manifest=$manifest; InstalledState=$installedState } { param($Releases,$Manifest,$InstalledState) Get-WintainiumEligibleRelease -Releases $Releases -Manifest $Manifest -InstalledState $InstalledState }
        @($result.EligibleReleases).Count | Should -Be 0
        @($result.Observations).Count | Should -Be 0
        $result.IsDeterministic | Should -BeTrue
    }
}
