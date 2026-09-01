$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium update target resolution' {
    It 'selects the greatest eligible release that has a selectable artifact' {
        $releases = @(
            [pscustomobject]@{ ReleaseId='release-3.0.0'; Version='3.0.0'; Channel='stable'; Artifacts=@() },
            [pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=@([pscustomobject]@{ Uri='https://example.test/app-2.0.0.msi'; Format='msi'; Architecture='x64' }) }
        )
        $manifest = [pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }

        $result = InModuleScope Wintainium.Core -Parameters @{ Releases=$releases; Manifest=$manifest } {
            param($Releases,$Manifest)
            Resolve-WintainiumUpdateTarget -EligibleReleases $Releases -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedRelease.ReleaseId | Should -Be 'release-2.0.0'
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app-2.0.0.msi'
        $result.ReasonCode | Should -Be 'TargetSelected'
        @($result.Observations).Count | Should -Be 2
        $result.Observations[0].ReasonCode | Should -Be 'NoSelectableArtifact'
        $result.IsDeterministic | Should -BeTrue
    }

    It 'selects the greatest version rather than provider input order' {
        $releases = @(
            [pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=@([pscustomobject]@{ Uri='https://example.test/app-2.msi'; Format='msi'; Architecture='x64' }) },
            [pscustomobject]@{ ReleaseId='release-3.0.0'; Version='3.0.0'; Channel='stable'; Artifacts=@([pscustomobject]@{ Uri='https://example.test/app-3.msi'; Format='msi'; Architecture='x64' }) }
        )
        $manifest = [pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }

        $result = InModuleScope Wintainium.Core -Parameters @{ Releases=$releases; Manifest=$manifest } {
            param($Releases,$Manifest)
            Resolve-WintainiumUpdateTarget -EligibleReleases $Releases -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedRelease.ReleaseId | Should -Be 'release-3.0.0'
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app-3.msi'
    }

    It 'uses input order as the tie breaker for equal selectable versions' {
        $releases = @(
            [pscustomobject]@{ ReleaseId='release-first'; Version='2.0.0'; Channel='stable'; Artifacts=@([pscustomobject]@{ Uri='https://example.test/first.msi'; Format='msi'; Architecture='x64' }) },
            [pscustomobject]@{ ReleaseId='release-second'; Version='2.0.0'; Channel='stable'; Artifacts=@([pscustomobject]@{ Uri='https://example.test/second.msi'; Format='msi'; Architecture='x64' }) }
        )
        $manifest = [pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }

        $result = InModuleScope Wintainium.Core -Parameters @{ Releases=$releases; Manifest=$manifest } {
            param($Releases,$Manifest)
            Resolve-WintainiumUpdateTarget -EligibleReleases $Releases -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedRelease.ReleaseId | Should -Be 'release-first'
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/first.msi'
    }

    It 'returns no target and preserves observations when no artifact is selectable' {
        $releases = @(
            [pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=@([pscustomobject]@{ Uri='https://example.test/app.zip'; Format='zip'; Architecture='x64' }) }
        )
        $manifest = [pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }

        $result = InModuleScope Wintainium.Core -Parameters @{ Releases=$releases; Manifest=$manifest } {
            param($Releases,$Manifest)
            Resolve-WintainiumUpdateTarget -EligibleReleases $Releases -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedRelease | Should -BeNullOrEmpty
        $result.SelectedArtifact | Should -BeNullOrEmpty
        $result.ReasonCode | Should -Be 'NoSelectableArtifact'
        @($result.Observations).Count | Should -Be 1
        $result.Observations[0].ArtifactSelection.Observations[0].ReasonCode | Should -Be 'FormatNotPermitted'
        $result.IsDeterministic | Should -BeTrue
    }

    It 'does not guess a target when selectable release versions cannot be ranked' {
        $releases = @(
            [pscustomobject]@{ ReleaseId='release-alpha'; Version='alpha'; Channel='stable'; Artifacts=@([pscustomobject]@{ Uri='https://example.test/alpha.msi'; Format='msi'; Architecture='x64' }) },
            [pscustomobject]@{ ReleaseId='release-beta'; Version='beta'; Channel='stable'; Artifacts=@([pscustomobject]@{ Uri='https://example.test/beta.msi'; Format='msi'; Architecture='x64' }) }
        )
        $manifest = [pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }

        $result = InModuleScope Wintainium.Core -Parameters @{ Releases=$releases; Manifest=$manifest } {
            param($Releases,$Manifest)
            Resolve-WintainiumUpdateTarget -EligibleReleases $Releases -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedRelease | Should -BeNullOrEmpty
        $result.SelectedArtifact | Should -BeNullOrEmpty
        $result.ReasonCode | Should -Be 'VersionRankingUnknown'
        $result.IsDeterministic | Should -BeFalse
    }

    It 'handles an empty eligible release set deterministically' {
        $manifest = [pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }

        $result = InModuleScope Wintainium.Core -Parameters @{ Manifest=$manifest } {
            param($Manifest)
            Resolve-WintainiumUpdateTarget -EligibleReleases @() -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedRelease | Should -BeNullOrEmpty
        $result.SelectedArtifact | Should -BeNullOrEmpty
        $result.ReasonCode | Should -Be 'NoSelectableArtifact'
        @($result.Observations).Count | Should -Be 0
        $result.IsDeterministic | Should -BeTrue
    }
}
