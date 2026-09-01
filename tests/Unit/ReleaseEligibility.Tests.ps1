$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

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

Describe 'Wintainium release eligibility' {
    It 'accepts a newer stable release under stable policy' {
        $release = New-TestRelease
        $manifest = New-TestManifest
        $installedState = New-TestInstalledState
        $result = InModuleScope Wintainium.Core -Parameters @{ Release = $release; Manifest = $manifest; InstalledState = $installedState } {
            param($Release, $Manifest, $InstalledState)
            Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState
        }
        $result.Eligible | Should -BeTrue
        $result.ReasonCode | Should -Be 'Eligible'
        $result.VersionComparison.Comparison | Should -Be 'Greater'
    }

    It 'rejects prereleases under stable policy' {
        $release = New-TestRelease -Channel 'prerelease'
        $manifest = New-TestManifest
        $installedState = New-TestInstalledState
        $result = InModuleScope Wintainium.Core -Parameters @{ Release = $release; Manifest = $manifest; InstalledState = $installedState } {
            param($Release, $Manifest, $InstalledState)
            Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState
        }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'ChannelNotPermitted'
    }

    It 'accepts prereleases under prerelease policy when newer' {
        $release = New-TestRelease -Channel 'prerelease'
        $manifest = New-TestManifest -Channel 'prerelease'
        $installedState = New-TestInstalledState
        $result = InModuleScope Wintainium.Core -Parameters @{ Release = $release; Manifest = $manifest; InstalledState = $installedState } {
            param($Release, $Manifest, $InstalledState)
            Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState
        }
        $result.Eligible | Should -BeTrue
    }

    It 'accepts both channels under any policy' {
        foreach ($channel in @('stable','prerelease')) {
            $release = New-TestRelease -Channel $channel
            $manifest = New-TestManifest -Channel 'any'
            $installedState = New-TestInstalledState
            $result = InModuleScope Wintainium.Core -Parameters @{ Release = $release; Manifest = $manifest; InstalledState = $installedState } {
                param($Release, $Manifest, $InstalledState)
                Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState
            }
            $result.Eligible | Should -BeTrue
        }
    }

    It 'rejects a deprecated release' {
        $release = New-TestRelease -Deprecated $true
        $manifest = New-TestManifest
        $installedState = New-TestInstalledState
        $result = InModuleScope Wintainium.Core -Parameters @{ Release = $release; Manifest = $manifest; InstalledState = $installedState } {
            param($Release, $Manifest, $InstalledState)
            Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState
        }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'DeprecatedRelease'
    }

    It 'rejects an equal version' {
        $release = New-TestRelease -Version '1.0.0'
        $manifest = New-TestManifest
        $installedState = New-TestInstalledState
        $result = InModuleScope Wintainium.Core -Parameters @{ Release = $release; Manifest = $manifest; InstalledState = $installedState } {
            param($Release, $Manifest, $InstalledState)
            Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState
        }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'NotNewer'
    }

    It 'rejects a downgrade' {
        $release = New-TestRelease -Version '0.9.0'
        $manifest = New-TestManifest
        $installedState = New-TestInstalledState
        $result = InModuleScope Wintainium.Core -Parameters @{ Release = $release; Manifest = $manifest; InstalledState = $installedState } {
            param($Release, $Manifest, $InstalledState)
            Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState
        }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'DowngradeNotPermitted'
    }

    It 'does not guess ordering for opaque versions' {
        $release = New-TestRelease -Version 'build-final'
        $manifest = New-TestManifest
        $installedState = New-TestInstalledState -Version 'build-initial'
        $result = InModuleScope Wintainium.Core -Parameters @{ Release = $release; Manifest = $manifest; InstalledState = $installedState } {
            param($Release, $Manifest, $InstalledState)
            Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState
        }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'VersionComparisonUnknown'
        $result.VersionComparison.Comparison | Should -Be 'Unknown'
    }

    It 'rejects missing version data' {
        $release = New-TestRelease -Version ''
        $manifest = New-TestManifest
        $installedState = New-TestInstalledState
        $result = InModuleScope Wintainium.Core -Parameters @{ Release = $release; Manifest = $manifest; InstalledState = $installedState } {
            param($Release, $Manifest, $InstalledState)
            Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState
        }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'InsufficientVersionData'
    }

    It 'rejects an unknown release channel without guessing' {
        $release = New-TestRelease -Channel 'preview'
        $manifest = New-TestManifest -Channel 'any'
        $installedState = New-TestInstalledState
        $result = InModuleScope Wintainium.Core -Parameters @{ Release = $release; Manifest = $manifest; InstalledState = $installedState } {
            param($Release, $Manifest, $InstalledState)
            Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState
        }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'UnknownReleaseChannel'
    }
}
