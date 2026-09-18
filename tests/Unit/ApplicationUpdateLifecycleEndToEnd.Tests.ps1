$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium application update lifecycle end-to-end regression' {
    It 'preserves one OperationId and authoritative state across every successful lifecycle boundary' {
        InModuleScope Wintainium.Core {
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
            $release=[pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='DiscoveryCompleted'; Releases=@([pscustomobject]@{ ReleaseId='release-2'; Version='2.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@([pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64'; Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('a'*64) }) }) }); Errors=@(); Warnings=@(); LogEvents=@() }
            $decision=[pscustomobject]@{ OperationId=$operationId; Status='UpdateAvailable'; IsUpdateAvailable=$true; SelectedRelease=$release.Releases[0]; SelectedArtifact=$release.Releases[0].Artifacts[0] }
            $download=[pscustomobject]@{ OperationId=$operationId; Status='Downloaded'; Uri='https://example.test/app.exe'; FileName='app.exe'; DestinationPath='/tmp/app.exe'; BytesWritten=10 }
            $verification=[pscustomobject]@{ OperationId=$operationId; Status='Verified'; Algorithm='SHA256'; ExpectedHash=('a'*64); ActualHash=('a'*64); DestinationPath='/tmp/app.exe' }
            $selection=[pscustomobject]@{ IsSelected=$true; InstallerPlugin=$installer; ArtifactFormat='exe' }
            $installation=[pscustomobject]@{ OperationId=$operationId; Status='Completed'; IsSuccessful=$true; ExitCode=0 }
            $reconciliationResult=[pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Reconciled'; Evidence=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='2.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example'; EvidenceSource='Fixture' }; Errors=@(); Warnings=@(); LogEvents=@() }
            $persistedState=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='2.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' }

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$operationId; IsValid=$true; Manifest=$manifest; ProviderPlugin=$provider; InstallerPlugin=$installer; ReconciliationPlugin=$reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' } }
            Mock Get-WintainiumUpdateDecision { $decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$OperationId; UpdateDecision=$decision; SelectedRelease=$decision.SelectedRelease; SelectedArtifact=$decision.SelectedArtifact } }
            Mock Invoke-WintainiumDownload { $download }
            Mock Invoke-WintainiumArtifactVerification { $verification }
            Mock Select-WintainiumInstaller { $selection }
            Mock New-WintainiumInstallerRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$OperationId; DownloadOperationId=$OperationId; Manifest=$manifest; Installer=$manifest.Installer; Artifact=[pscustomobject]@{ Path='/tmp/app.exe'; Uri='https://example.test/app.exe'; FileName='app.exe' } }; Errors=@() } }
            Mock New-WintainiumInstallerInvocation { [pscustomobject]@{ IsValid=$true; Invocation=[pscustomobject]@{ OperationId=$OperationId; DownloadOperationId=$OperationId; PluginId=$installer.PluginId; PluginModulePath='/tmp/installer.psm1'; ArtifactPath='/tmp/app.exe'; ArtifactFormat='exe'; Settings=@{} }; Error=$null } }
            Mock Invoke-WintainiumInstallerOperation { $installation }
            Mock Invoke-WintainiumReconciliationOperation { $reconciliationResult }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation { [pscustomobject]@{ OperationId=$OperationId; IsSuccessful=$true; Status='Persisted'; State=$persistedState; Persisted=$true; ReasonCode='AuthoritativeEvidencePersisted'; Errors=@() } }

            $result=Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeTrue
            $result.OperationId | Should -Be $operationId
            $result.State.Status | Should -Be 'Completed'
            @($result.StageResults).Count | Should -Be 8
            $result.StageResults[-1].Execution.Result.AuthoritativeStateResult.Status | Should -Be 'Persisted'
            $result.StageResults[-1].Execution.Result.AuthoritativeStateResult.State.Version | Should -Be '2.0.0'
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 1 -Exactly -ParameterFilter { $OperationId -eq $operationId -and $ApplicationId -eq 'example.app' }
            Should -Invoke Invoke-WintainiumArtifactVerification -Times 1 -Exactly -ParameterFilter { $OperationId -eq $operationId }
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 1 -Exactly -ParameterFilter { $Request.OperationId -eq $operationId }
        }
    }

    It 'does not persist or replace authoritative state when reconciliation evidence is Unknown' {
        InModuleScope Wintainium.Core {
            $operationId=[guid]::NewGuid().ToString()
            $manifest=[pscustomobject]@{
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
            $download=[pscustomobject]@{ OperationId=$operationId; Status='Downloaded'; Uri='https://example.test/app.exe'; FileName='app.exe'; DestinationPath='/tmp/app.exe'; BytesWritten=10 }
            $verification=[pscustomobject]@{ OperationId=$operationId; Status='Verified'; IsSuccessful=$true; Algorithm='SHA256'; ExpectedHash=('a'*64); ActualHash=('a'*64); DestinationPath='/tmp/app.exe' }
            $selection=[pscustomobject]@{ IsSelected=$true; InstallerPlugin=$installer; ArtifactFormat='exe' }
            $installation=[pscustomobject]@{ OperationId=$operationId; Status='Completed'; IsSuccessful=$true; ExitCode=0 }
            $reconciliationResult=[pscustomobject]@{
                OperationId=$operationId
                IsSuccessful=$true
                Status='Reconciled'
                Evidence=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Unknown'; EvidenceSource='Fixture' }
                Errors=@()
                Warnings=@()
                LogEvents=@()
            }
            $priorState=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' }

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$operationId; IsValid=$true; Manifest=$manifest; ProviderPlugin=$provider; InstallerPlugin=$installer; ReconciliationPlugin=$reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $release }
            Mock Get-WintainiumInstalledApplicationState { $priorState }
            Mock Get-WintainiumUpdateDecision { $decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$operationId; UpdateDecision=$decision; SelectedRelease=$decision.SelectedRelease; SelectedArtifact=$decision.SelectedArtifact } }
            Mock Invoke-WintainiumDownload { $download }
            Mock Invoke-WintainiumArtifactVerification { $verification }
            Mock Select-WintainiumInstaller { $selection }
            Mock New-WintainiumInstallerRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId; DownloadOperationId=$operationId; Manifest=$manifest; Installer=$manifest.Installer; Artifact=[pscustomobject]@{ Path='/tmp/app.exe'; Uri='https://example.test/app.exe'; FileName='app.exe' } }; Errors=@() } }
            Mock New-WintainiumInstallerInvocation { [pscustomobject]@{ IsValid=$true; Invocation=[pscustomobject]@{ OperationId=$operationId; DownloadOperationId=$operationId; PluginId=$installer.PluginId; PluginModulePath='/tmp/installer.psm1'; ArtifactPath='/tmp/app.exe'; ArtifactFormat='exe'; Settings=@{} }; Error=$null } }
            Mock Invoke-WintainiumInstallerOperation { $installation }
            Mock Invoke-WintainiumReconciliationOperation { $reconciliationResult }
            Mock Set-WintainiumInstalledApplicationState { throw 'state persistence must not occur for Unknown evidence' }

            $output=Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $output.IsSuccessful | Should -BeTrue
            $output.OperationId | Should -Be $operationId
            $output.State.Status | Should -Be 'Completed'
            $output.StageResults[-1].Execution.Result.AuthoritativeStateResult.Status | Should -Be 'Preserved'
            $output.StageResults[-1].Execution.Result.AuthoritativeStateResult.ReasonCode | Should -Be 'UnknownEvidencePreserved'
            $output.StageResults[-1].Execution.Result.AuthoritativeStateResult.Persisted | Should -BeFalse
            $output.StageResults[-1].Execution.Result.AuthoritativeStateResult.State.Version | Should -Be '1.0.0'
            Should -Invoke Set-WintainiumInstalledApplicationState -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 1 -Exactly -ParameterFilter { $Request.OperationId -eq $operationId }
        }
    }
}
