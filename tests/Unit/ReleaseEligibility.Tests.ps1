$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium release eligibility' {
    InModuleScope Wintainium.Core {
        function New-TestManifest {
            param([string]$Channel = 'stable')
            [pscustomobject]@{ Release = [pscustomobject]@{ channel = $Channel } }
        }

        function New-TestInstalledState {
            param([string]$Version = '1.0.0')
            [pscustomobject]@{ ApplicationId = 'example.app'; Version = $Version; Architecture = 'x64'; Channel = 'stable'; InstallationState = 'Installed' }
        }

        function New-TestRelease {
            param([string]$Version = '2.0.0', [string]$Channel = 'stable', [bool]$Deprecated = $false)
            [pscustomobject]@{ ReleaseId = "release-$Version"; Version = $Version; Channel = $Channel; Deprecated = $Deprecated; Artifacts = @() }
        }

        It 'accepts a newer stable release under stable policy' {
            $result = Test-WintainiumReleaseEligibility -Release (New-TestRelease) -Manifest (New-TestManifest) -InstalledState (New-TestInstalledState)
            $result.Eligible | Should -BeTrue
            $result.ReasonCode | Should -Be 'Eligible'
            $result.VersionComparison.Comparison | Should -Be 'Greater'
        }

        It 'rejects prereleases under stable policy' {
            $result = Test-WintainiumReleaseEligibility -Release (New-TestRelease -Channel 'prerelease') -Manifest (New-TestManifest) -InstalledState (New-TestInstalledState)
            $result.Eligible | Should -BeFalse
            $result.ReasonCode | Should -Be 'ChannelNotPermitted'
        }

        It 'accepts prereleases under prerelease policy when newer' {
            $result = Test-WintainiumReleaseEligibility -Release (New-TestRelease -Channel 'prerelease') -Manifest (New-TestManifest -Channel 'prerelease') -InstalledState (New-TestInstalledState)
            $result.Eligible | Should -BeTrue
        }

        It 'accepts both channels under any policy' {
            foreach ($channel in @('stable','prerelease')) {
                $result = Test-WintainiumReleaseEligibility -Release (New-TestRelease -Channel $channel) -Manifest (New-TestManifest -Channel 'any') -InstalledState (New-TestInstalledState)
                $result.Eligible | Should -BeTrue
            }
        }

        It 'rejects a deprecated release' {
            $result = Test-WintainiumReleaseEligibility -Release (New-TestRelease -Deprecated $true) -Manifest (New-TestManifest) -InstalledState (New-TestInstalledState)
            $result.Eligible | Should -BeFalse
            $result.ReasonCode | Should -Be 'DeprecatedRelease'
        }

        It 'rejects an equal version' {
            $result = Test-WintainiumReleaseEligibility -Release (New-TestRelease -Version '1.0.0') -Manifest (New-TestManifest) -InstalledState (New-TestInstalledState)
            $result.Eligible | Should -BeFalse
            $result.ReasonCode | Should -Be 'NotNewer'
        }

        It 'rejects a downgrade' {
            $result = Test-WintainiumReleaseEligibility -Release (New-TestRelease -Version '0.9.0') -Manifest (New-TestManifest) -InstalledState (New-TestInstalledState)
            $result.Eligible | Should -BeFalse
            $result.ReasonCode | Should -Be 'DowngradeNotPermitted'
        }

        It 'does not guess ordering for opaque versions' {
            $result = Test-WintainiumReleaseEligibility -Release (New-TestRelease -Version 'build-final') -Manifest (New-TestManifest) -InstalledState (New-TestInstalledState -Version 'build-initial')
            $result.Eligible | Should -BeFalse
            $result.ReasonCode | Should -Be 'VersionComparisonUnknown'
            $result.VersionComparison.Comparison | Should -Be 'Unknown'
        }

        It 'rejects missing version data' {
            $result = Test-WintainiumReleaseEligibility -Release (New-TestRelease -Version '') -Manifest (New-TestManifest) -InstalledState (New-TestInstalledState)
            $result.Eligible | Should -BeFalse
            $result.ReasonCode | Should -Be 'InsufficientVersionData'
        }

        It 'rejects an unknown release channel without guessing' {
            $result = Test-WintainiumReleaseEligibility -Release (New-TestRelease -Channel 'preview') -Manifest (New-TestManifest -Channel 'any') -InstalledState (New-TestInstalledState)
            $result.Eligible | Should -BeFalse
            $result.ReasonCode | Should -Be 'UnknownReleaseChannel'
        }
    }
}
