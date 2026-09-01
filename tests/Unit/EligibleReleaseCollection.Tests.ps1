$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium eligible release collection' {
    InModuleScope Wintainium.Core {
        function New-TestManifest {
            param([string]$Channel = 'stable')
            [pscustomobject]@{ Release = [pscustomobject]@{ channel = $Channel } }
        }
        function New-TestInstalledState {
            [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        }
        function New-TestRelease {
            param([string]$Version,[string]$Channel='stable')
            [pscustomobject]@{ ReleaseId="release-$Version-$Channel"; Version=$Version; Channel=$Channel; Artifacts=@() }
        }

        It 'returns eligible releases while preserving input order' {
            $releases=@(
                (New-TestRelease -Version '1.0.0'),
                (New-TestRelease -Version '3.0.0'),
                (New-TestRelease -Version '2.0.0')
            )
            $result=Get-WintainiumEligibleRelease -Releases $releases -Manifest (New-TestManifest) -InstalledState (New-TestInstalledState)
            @($result.EligibleReleases).Count | Should -Be 2
            $result.EligibleReleases[0].Version | Should -Be '3.0.0'
            $result.EligibleReleases[1].Version | Should -Be '2.0.0'
            $result.IsDeterministic | Should -BeTrue
        }

        It 'retains rejection observations for excluded releases' {
            $releases=@(
                (New-TestRelease -Version '1.0.0'),
                (New-TestRelease -Version '2.0.0' -Channel 'prerelease')
            )
            $result=Get-WintainiumEligibleRelease -Releases $releases -Manifest (New-TestManifest) -InstalledState (New-TestInstalledState)
            @($result.EligibleReleases).Count | Should -Be 0
            @($result.Observations).Count | Should -Be 2
            $result.Observations[0].ReasonCode | Should -Be 'NotNewer'
            $result.Observations[1].ReasonCode | Should -Be 'ChannelNotPermitted'
        }

        It 'handles an empty release set deterministically' {
            $result=Get-WintainiumEligibleRelease -Releases @() -Manifest (New-TestManifest) -InstalledState (New-TestInstalledState)
            @($result.EligibleReleases).Count | Should -Be 0
            @($result.Observations).Count | Should -Be 0
            $result.IsDeterministic | Should -BeTrue
        }
    }
}
