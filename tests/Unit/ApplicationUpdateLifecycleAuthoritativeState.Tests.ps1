$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium application lifecycle authoritative state integration' {
    BeforeAll {
        InModuleScope Wintainium.Core {
            $script:AuthoritativeLifecycleFixtureFactory = {

                $operationId = [guid]::NewGuid().ToString()
                $manifest = [pscustomobject]@{
                    Id='example.app'
                    Source=[pscustomobject]@{ pluginId='Wintainium.provider.valid-fixture'; requiredContractVersion='1'; settings=@{} }
                    Installer=[pscustomobject]@{ pluginId='Wintainium.installer.valid-fixture'; requiredContractVersion='1'; settings=@{} }
                    Reconciliation=[pscustomobject]@{ pluginId='Wintainium.reconciliation.valid-fixture'; requiredContractVersion='1'; settings=@{} }
                    Release=[pscustomobject]@{ channel='stable' }
                    Artifact=[pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false }
                }
                $provider=[pscustomobject]@{ PluginId='Wintainium.provider.valid-fixture'; PluginType='Provider' }
                $installer=[pscustomobject]@{ PluginId='Wintainium.installer.valid-fixture'; PluginType='Installer' }
                $reconciliation=[pscustomobject]@{ PluginId='Wintainium.reconciliation.valid-fixture'; PluginType='Reconciliation' }
                $release=[pscustomobject]@{
                    OperationId=$operationId
                    IsSuccessful=$true
                    Status='DiscoveryCompleted'
                    Releases=@([pscustomobject]@{
                        ReleaseId='release-2'
                        Version='2.0.0'
                        Channel='stable'
                        Deprecated=$false
                        Artifacts=@([pscustomobject]@{
                            Uri='https://example.test/app.exe'
                            Format='exe'
                            Architecture='x64'
                            Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('a'*64) })
                        })
                    })
                    Errors=@()
                    Warnings=@()
                    LogEvents=@()
                }
                $decision=[pscustomobject]@{
                    OperationId=$operationId
                    Status='UpdateAvailable'
                    IsUpdateAvailable=$true
                    SelectedRelease=$release.Releases[0]
                    SelectedArtifact=$release.Releases[0].Artifacts[0]
                }
                [pscustomobject]@{
                    OperationId=$operationId
                    Manifest=$manifest
                    Provider=$provider
                    Installer=$installer
                    Reconciliation=$reconciliation
                    Release=$release
                    Decision=$decision
                }
            }
        }
    }

    It 'persists authoritative installed evidence inside the Reconciliation stage' {
        InModuleScope Wintainium.Core {
            $fixture = & $script:AuthoritativeLifecycleFixtureFactory
            $priorState=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' }
            $download=[pscustomobject]@{ OperationId=$fixture.OperationId; Status='Downloaded'; Uri='https://example.test/app.exe'; FileName='app.exe'; DestinationPath='/tmp/app.exe'; BytesWritten=10 }
            $verification=[pscustomobject]@{ OperationId=$fixture.OperationId; Status='Verified'; IsSuccessful=$true; Algorithm='SHA256'; ExpectedHash=('a'*64); ActualHash=('a'*64); DestinationPath='/tmp/app.exe' }
            $selection=[pscustomobject]@{ IsSelected=$true; InstallerPlugin=$fixture.Installer; ArtifactFormat='exe' }
            $installation=[pscustomobject]@{ OperationId=$fixture.OperationId; Status='Completed'; IsSuccessful=$true; ExitCode=0 }
            $reconciliationResult=[pscustomobject]@{ OperationId=$fixture.OperationId; IsSuccessful=$true; Status='Reconciled'; Evidence=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='2.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example'; EvidenceSource='Fixture' }; Errors=@(); Warnings=@(); LogEvents=@() }
            $authoritative=[pscustomobject]@{ OperationId=$fixture.OperationId; IsSuccessful=$true; Status='Persisted'; State=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='2.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' }; Persisted=$true; ReasonCode='AuthoritativeEvidencePersisted'; Errors=@() }

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$fixture.OperationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$fixture.OperationId; IsValid=$true; Manifest=$fixture.Manifest; ProviderPlugin=$fixture.Provider; InstallerPlugin=$fixture.Installer; ReconciliationPlugin=$fixture.Reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $fixture.Release }
            Mock Get-WintainiumInstalledApplicationState { $priorState }
            Mock Get-WintainiumUpdateDecision { $fixture.Decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$fixture.OperationId; UpdateDecision=$fixture.Decision; SelectedRelease=$fixture.Decision.SelectedRelease; SelectedArtifact=$fixture.Decision.SelectedArtifact } }
            Mock Invoke-WintainiumDownload { $download }
            Mock Invoke-WintainiumArtifactVerification { $verification }
            Mock Select-WintainiumInstaller { $selection }
            Mock New-WintainiumInstallerRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$fixture.OperationId; DownloadOperationId=$fixture.OperationId; Manifest=$fixture.Manifest; Installer=$fixture.Manifest.Installer; Artifact=[pscustomobject]@{ Path='/tmp/app.exe'; Uri='https://example.test/app.exe'; FileName='app.exe' } }; Errors=@() } }
            Mock New-WintainiumInstallerInvocation { [pscustomobject]@{ IsValid=$true; Invocation=[pscustomobject]@{ OperationId=$fixture.OperationId; DownloadOperationId=$fixture.OperationId; PluginId=$fixture.Installer.PluginId; PluginModulePath='/tmp/installer.psm1'; ArtifactPath='/tmp/app.exe'; ArtifactFormat='exe'; Settings=@{} }; Error=$null } }
            Mock Invoke-WintainiumInstallerOperation { $installation }
            Mock Invoke-WintainiumReconciliationOperation { $reconciliationResult }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation { $authoritative }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeTrue
            $result.OperationId | Should -Be $fixture.OperationId
            $result.State.Status | Should -Be 'Completed'
            $result.StageResults[-1].Execution.Result.AuthoritativeStateResult.Status | Should -Be 'Persisted'
            $result.StageResults[-1].Execution.Result.AuthoritativeStateResult.State.Version | Should -Be '2.0.0'
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 1 -Exactly -ParameterFilter { $OperationId -eq $fixture.OperationId -and $ApplicationId -eq 'example.app' -and $ReconciliationResult.OperationId -eq $fixture.OperationId -and $PriorState.Version -eq '1.0.0' }
        }
    }

    It 'preserves a successful lifecycle when authoritative reconciliation preserves Unknown evidence' {
        InModuleScope Wintainium.Core {
            $fixture = & $script:AuthoritativeLifecycleFixtureFactory
            $download=[pscustomobject]@{ OperationId=$fixture.OperationId; Status='Downloaded'; Uri='https://example.test/app.exe'; FileName='app.exe'; DestinationPath='/tmp/app.exe'; BytesWritten=10 }
            $verification=[pscustomobject]@{ OperationId=$fixture.OperationId; Status='Verified'; IsSuccessful=$true; Algorithm='SHA256'; ExpectedHash=('a'*64); ActualHash=('a'*64); DestinationPath='/tmp/app.exe' }
            $selection=[pscustomobject]@{ IsSelected=$true; InstallerPlugin=$fixture.Installer; ArtifactFormat='exe' }
            $installation=[pscustomobject]@{ OperationId=$fixture.OperationId; Status='Completed'; IsSuccessful=$true; ExitCode=0 }
            $reconciliationResult=[pscustomobject]@{ OperationId=$fixture.OperationId; IsSuccessful=$true; Status='Reconciled'; Evidence=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Unknown'; EvidenceSource='Fixture' }; Errors=@(); Warnings=@(); LogEvents=@() }
            $authoritative=[pscustomobject]@{ OperationId=$fixture.OperationId; IsSuccessful=$true; Status='Preserved'; State=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0' }; Persisted=$false; ReasonCode='UnknownEvidencePreserved'; Errors=@() }

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$fixture.OperationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$fixture.OperationId; IsValid=$true; Manifest=$fixture.Manifest; ProviderPlugin=$fixture.Provider; InstallerPlugin=$fixture.Installer; ReconciliationPlugin=$fixture.Reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $fixture.Release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0' } }
            Mock Get-WintainiumUpdateDecision { $fixture.Decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$fixture.OperationId; UpdateDecision=$fixture.Decision; SelectedRelease=$fixture.Decision.SelectedRelease; SelectedArtifact=$fixture.Decision.SelectedArtifact } }
            Mock Invoke-WintainiumDownload { $download }
            Mock Invoke-WintainiumArtifactVerification { $verification }
            Mock Select-WintainiumInstaller { $selection }
            Mock New-WintainiumInstallerRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$fixture.OperationId; DownloadOperationId=$fixture.OperationId; Manifest=$fixture.Manifest; Installer=$fixture.Manifest.Installer; Artifact=[pscustomobject]@{ Path='/tmp/app.exe'; Uri='https://example.test/app.exe'; FileName='app.exe' } }; Errors=@() } }
            Mock New-WintainiumInstallerInvocation { [pscustomobject]@{ IsValid=$true; Invocation=[pscustomobject]@{ OperationId=$fixture.OperationId; DownloadOperationId=$fixture.OperationId; PluginId=$fixture.Installer.PluginId; PluginModulePath='/tmp/installer.psm1'; ArtifactPath='/tmp/app.exe'; ArtifactFormat='exe'; Settings=@{} }; Error=$null } }
            Mock Invoke-WintainiumInstallerOperation { $installation }
            Mock Invoke-WintainiumReconciliationOperation { $reconciliationResult }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation { $authoritative }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeTrue
            $result.StageResults[-1].Execution.Result.AuthoritativeStateResult.Status | Should -Be 'Preserved'
            $result.StageResults[-1].Execution.Result.AuthoritativeStateResult.Persisted | Should -BeFalse
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 1 -Exactly
        }
    }

    It 'turns authoritative persistence failure into a native Reconciliation stage failure' {
        InModuleScope Wintainium.Core {
            $fixture = & $script:AuthoritativeLifecycleFixtureFactory
            $download=[pscustomobject]@{ OperationId=$fixture.OperationId; Status='Downloaded'; Uri='https://example.test/app.exe'; FileName='app.exe'; DestinationPath='/tmp/app.exe'; BytesWritten=10 }
            $verification=[pscustomobject]@{ OperationId=$fixture.OperationId; Status='Verified'; IsSuccessful=$true; Algorithm='SHA256'; ExpectedHash=('a'*64); ActualHash=('a'*64); DestinationPath='/tmp/app.exe' }
            $selection=[pscustomobject]@{ IsSelected=$true; InstallerPlugin=$fixture.Installer; ArtifactFormat='exe' }
            $installation=[pscustomobject]@{ OperationId=$fixture.OperationId; Status='Completed'; IsSuccessful=$true; ExitCode=0 }
            $reconciliationResult=[pscustomobject]@{ OperationId=$fixture.OperationId; IsSuccessful=$true; Status='Reconciled'; Evidence=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='2.0.0'; EvidenceSource='Fixture' }; Errors=@(); Warnings=@(); LogEvents=@() }
            $authoritative=[pscustomobject]@{ OperationId=$fixture.OperationId; IsSuccessful=$false; Status='Failed'; Persisted=$false; ReasonCode='InstalledStatePersistenceFailed'; Errors=@([pscustomobject]@{ Code='InstalledStatePersistenceFailed'; Message='fixture persistence failure' }) }

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$fixture.OperationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$fixture.OperationId; IsValid=$true; Manifest=$fixture.Manifest; ProviderPlugin=$fixture.Provider; InstallerPlugin=$fixture.Installer; ReconciliationPlugin=$fixture.Reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $fixture.Release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0' } }
            Mock Get-WintainiumUpdateDecision { $fixture.Decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$fixture.OperationId; UpdateDecision=$fixture.Decision; SelectedRelease=$fixture.Decision.SelectedRelease; SelectedArtifact=$fixture.Decision.SelectedArtifact } }
            Mock Invoke-WintainiumDownload { $download }
            Mock Invoke-WintainiumArtifactVerification { $verification }
            Mock Select-WintainiumInstaller { $selection }
            Mock New-WintainiumInstallerRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$fixture.OperationId; DownloadOperationId=$fixture.OperationId; Manifest=$fixture.Manifest; Installer=$fixture.Manifest.Installer; Artifact=[pscustomobject]@{ Path='/tmp/app.exe'; Uri='https://example.test/app.exe'; FileName='app.exe' } }; Errors=@() } }
            Mock New-WintainiumInstallerInvocation { [pscustomobject]@{ IsValid=$true; Invocation=[pscustomobject]@{ OperationId=$fixture.OperationId; DownloadOperationId=$fixture.OperationId; PluginId=$fixture.Installer.PluginId; PluginModulePath='/tmp/installer.psm1'; ArtifactPath='/tmp/app.exe'; ArtifactFormat='exe'; Settings=@{} }; Error=$null } }
            Mock Invoke-WintainiumInstallerOperation { $installation }
            Mock Invoke-WintainiumReconciliationOperation { $reconciliationResult }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation { $authoritative }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeFalse
            $result.State.Status | Should -Be 'Failed'
            $result.State.FailedStage.Name | Should -Be 'Reconciliation'
            $result.Error.Code | Should -Be 'OrchestrationStageExecutionFailed'
            $result.StageResults[-1].Execution.Result.Status | Should -Be 'Failed'
            $result.StageResults[-1].Execution.Result.FailureKind | Should -Be 'AuthoritativeStateReconciliationFailed'
            $result.StageResults[-1].Execution.Result.AuthoritativeStateResult.ReasonCode | Should -Be 'InstalledStatePersistenceFailed'
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 1 -Exactly
        }
    }

    It 'does not reconcile or persist state for a no-update lifecycle' {
        InModuleScope Wintainium.Core {
            $fixture = & $script:AuthoritativeLifecycleFixtureFactory
            $decision = [pscustomobject]@{
                OperationId=$fixture.OperationId
                Status='NoUpdateAvailable'
                IsUpdateAvailable=$false
                SelectedRelease=$null
                SelectedArtifact=$null
            }

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$fixture.OperationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$fixture.OperationId; IsValid=$true; Manifest=$fixture.Manifest; ProviderPlugin=$fixture.Provider; InstallerPlugin=$fixture.Installer; ReconciliationPlugin=$fixture.Reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $fixture.Release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0' } }
            Mock Get-WintainiumUpdateDecision { $decision }
            Mock Invoke-WintainiumReconciliationOperation { throw 'reconciliation must not execute for a no-update lifecycle' }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation { throw 'authoritative persistence must not execute for a no-update lifecycle' }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeTrue
            $result.StageResults[-1].Execution.Result.Status | Should -Be 'Skipped'
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 0 -Exactly
        }
    }
}
