$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium release eligibility' {
    It 'accepts a newer stable release under stable policy' {
        $release = [pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@() }
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='stable' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Release=$release; Manifest=$manifest; InstalledState=$installedState } {
            param($Release,$Manifest,$InstalledState)
            Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState
        }
        $result.Eligible | Should -BeTrue
        $result.ReasonCode | Should -Be 'Eligible'
        $result.VersionComparison.Comparison | Should -Be 'Greater'
    }

    It 'rejects prereleases under stable policy' {
        $release = [pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='prerelease'; Deprecated=$false; Artifacts=@() }
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='stable' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Release=$release; Manifest=$manifest; InstalledState=$installedState } { param($Release,$Manifest,$InstalledState) Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'ChannelNotPermitted'
    }

    It 'accepts prereleases under prerelease policy when newer' {
        $release = [pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='prerelease'; Deprecated=$false; Artifacts=@() }
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='prerelease' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Release=$release; Manifest=$manifest; InstalledState=$installedState } { param($Release,$Manifest,$InstalledState) Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState }
        $result.Eligible | Should -BeTrue
    }

    It 'accepts both channels under any policy' {
        foreach ($channel in @('stable','prerelease')) {
            $release = [pscustomobject]@{ ReleaseId="release-2.0.0-$channel"; Version='2.0.0'; Channel=$channel; Deprecated=$false; Artifacts=@() }
            $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='any' } }
            $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
            $result = InModuleScope Wintainium.Core -Parameters @{ Release=$release; Manifest=$manifest; InstalledState=$installedState } { param($Release,$Manifest,$InstalledState) Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState }
            $result.Eligible | Should -BeTrue
        }
    }

    It 'rejects a deprecated release' {
        $release = [pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Deprecated=$true; Artifacts=@() }
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='stable' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Release=$release; Manifest=$manifest; InstalledState=$installedState } { param($Release,$Manifest,$InstalledState) Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'DeprecatedRelease'
    }

    It 'rejects an equal version' {
        $release = [pscustomobject]@{ ReleaseId='release-1.0.0'; Version='1.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@() }
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='stable' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Release=$release; Manifest=$manifest; InstalledState=$installedState } { param($Release,$Manifest,$InstalledState) Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'NotNewer'
    }

    It 'rejects a downgrade' {
        $release = [pscustomobject]@{ ReleaseId='release-0.9.0'; Version='0.9.0'; Channel='stable'; Deprecated=$false; Artifacts=@() }
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='stable' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Release=$release; Manifest=$manifest; InstalledState=$installedState } { param($Release,$Manifest,$InstalledState) Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'DowngradeNotPermitted'
    }

    It 'does not guess ordering for opaque versions' {
        $release = [pscustomobject]@{ ReleaseId='release-build-final'; Version='build-final'; Channel='stable'; Deprecated=$false; Artifacts=@() }
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='stable' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='build-initial'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Release=$release; Manifest=$manifest; InstalledState=$installedState } { param($Release,$Manifest,$InstalledState) Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'VersionComparisonUnknown'
        $result.VersionComparison.Comparison | Should -Be 'Unknown'
    }

    It 'rejects missing version data' {
        $release = [pscustomobject]@{ ReleaseId='release-missing'; Version=''; Channel='stable'; Deprecated=$false; Artifacts=@() }
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='stable' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Release=$release; Manifest=$manifest; InstalledState=$installedState } { param($Release,$Manifest,$InstalledState) Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'InsufficientVersionData'
    }

    It 'rejects an unknown release channel without guessing' {
        $release = [pscustomobject]@{ ReleaseId='release-2.0.0-preview'; Version='2.0.0'; Channel='preview'; Deprecated=$false; Artifacts=@() }
        $manifest = [pscustomobject]@{ Release=[pscustomobject]@{ channel='any' } }
        $installedState = [pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Release=$release; Manifest=$manifest; InstalledState=$installedState } { param($Release,$Manifest,$InstalledState) Test-WintainiumReleaseEligibility -Release $Release -Manifest $Manifest -InstalledState $InstalledState }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'UnknownReleaseChannel'
    }
}
