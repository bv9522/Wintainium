$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium final update decision' {
    It 'returns an update target for a newer eligible release with a selectable artifact' {
        $manifest=[pscustomobject]@{ Id='example.app'; Release=[pscustomobject]@{channel='stable'}; artifact=[pscustomobject]@{formats=@('msi');architectures=@('x64','neutral');allowUnknownArchitecture=$false} }
        $state=[pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $provider=[pscustomobject]@{ IsSuccessful=$true; Releases=@([pscustomobject]@{ReleaseId='release-2';Version='2.0.0';Channel='stable';Deprecated=$false;Artifacts=@([pscustomobject]@{Uri='https://example.test/app.msi';Format='msi';Architecture='x64'})}) }
        $decisionInput=[pscustomobject]@{Manifest=$manifest;InstalledState=$state;ProviderResult=$provider}
        $result=InModuleScope Wintainium.Core -Parameters @{DecisionInput=$decisionInput} { param($DecisionInput) Get-WintainiumUpdateDecision -UpdateDecisionInput $DecisionInput -MachineArchitecture 'x64' }
        $result.Status | Should -Be 'UpdateAvailable'
        $result.IsUpdateAvailable | Should -BeTrue
        $result.SelectedRelease.ReleaseId | Should -Be 'release-2'
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app.msi'
        $result.ReleaseEligibility.IsDeterministic | Should -BeTrue
        $result.TargetResolution.ReasonCode | Should -Be 'TargetSelected'
    }

    It 'returns no update when discovery succeeds but no release is eligible' {
        $manifest=[pscustomobject]@{ Id='example.app'; Release=[pscustomobject]@{channel='stable'}; artifact=[pscustomobject]@{formats=@('msi');architectures=@('x64','neutral');allowUnknownArchitecture=$false} }
        $state=[pscustomobject]@{ ApplicationId='example.app'; Version='2.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $provider=[pscustomobject]@{ IsSuccessful=$true; Releases=@([pscustomobject]@{ReleaseId='release-1';Version='1.0.0';Channel='stable';Deprecated=$false;Artifacts=@()}) }
        $decisionInput=[pscustomobject]@{Manifest=$manifest;InstalledState=$state;ProviderResult=$provider}
        $result=InModuleScope Wintainium.Core -Parameters @{DecisionInput=$decisionInput} { param($DecisionInput) Get-WintainiumUpdateDecision -UpdateDecisionInput $DecisionInput -MachineArchitecture 'x64' }
        $result.Status | Should -Be 'NoUpdateAvailable'
        $result.IsUpdateAvailable | Should -BeFalse
        $result.ReasonCode | Should -Be 'NoEligibleRelease'
        $result.SelectedRelease | Should -BeNullOrEmpty
    }

    It 'returns no update when eligible releases have no selectable artifact' {
        $manifest=[pscustomobject]@{ Id='example.app'; Release=[pscustomobject]@{channel='stable'}; artifact=[pscustomobject]@{formats=@('msi');architectures=@('x64','neutral');allowUnknownArchitecture=$false} }
        $state=[pscustomobject]@{ ApplicationId='example.app'; Version='1.0.0'; Architecture='x64'; Channel='stable'; InstallationState='Installed' }
        $provider=[pscustomobject]@{ IsSuccessful=$true; Releases=@([pscustomobject]@{ReleaseId='release-2';Version='2.0.0';Channel='stable';Deprecated=$false;Artifacts=@([pscustomobject]@{Uri='https://example.test/app.zip';Format='zip';Architecture='x64'})}) }
        $decisionInput=[pscustomobject]@{Manifest=$manifest;InstalledState=$state;ProviderResult=$provider}
        $result=InModuleScope Wintainium.Core -Parameters @{DecisionInput=$decisionInput} { param($DecisionInput) Get-WintainiumUpdateDecision -UpdateDecisionInput $DecisionInput -MachineArchitecture 'x64' }
        $result.Status | Should -Be 'NoUpdateAvailable'
        $result.ReasonCode | Should -Be 'NoSelectableArtifact'
        $result.TargetResolution.Observations[0].ArtifactSelection.SelectedArtifact | Should -BeNullOrEmpty
    }

    It 'does not make an update decision after unsuccessful provider discovery' {
        $decisionInput=[pscustomobject]@{Manifest=[pscustomobject]@{Id='example.app'};InstalledState=[pscustomobject]@{ApplicationId='example.app';InstallationState='Installed'};ProviderResult=[pscustomobject]@{IsSuccessful=$false;Releases=@()}}
        $result=InModuleScope Wintainium.Core -Parameters @{DecisionInput=$decisionInput} { param($DecisionInput) Get-WintainiumUpdateDecision -UpdateDecisionInput $DecisionInput -MachineArchitecture 'x64' }
        $result.Status | Should -Be 'ProviderDiscoveryUnsuccessful'
        $result.IsUpdateAvailable | Should -BeNullOrEmpty
        $result.ReasonCode | Should -Be 'ProviderDiscoveryUnsuccessful'
    }

    It 'does not turn a not-installed application into an update' {
        $decisionInput=[pscustomobject]@{Manifest=[pscustomobject]@{Id='example.app'};InstalledState=[pscustomobject]@{ApplicationId='example.app';InstallationState='NotInstalled'};ProviderResult=[pscustomobject]@{IsSuccessful=$true;Releases=@()}}
        $result=InModuleScope Wintainium.Core -Parameters @{DecisionInput=$decisionInput} { param($DecisionInput) Get-WintainiumUpdateDecision -UpdateDecisionInput $DecisionInput -MachineArchitecture 'x64' }
        $result.Status | Should -Be 'ApplicationNotInstalled'
        $result.IsUpdateAvailable | Should -BeFalse
    }
}
