$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium application update lifecycle failure matrix' {
    BeforeEach {
        InModuleScope Wintainium.Core {
        $script:operationId = [guid]::NewGuid().ToString()
        $script:manifest = [pscustomobject]@{
            Id = 'example.app'
            Source = [pscustomobject]@{ pluginId='Wintainium.provider.valid-fixture'; requiredContractVersion='1'; settings=@{} }
            Installer = [pscustomobject]@{ pluginId='Wintainium.installer.valid-fixture'; requiredContractVersion='1'; settings=@{} }
            Reconciliation = [pscustomobject]@{ pluginId='Wintainium.reconciliation.valid-fixture'; requiredContractVersion='1'; settings=@{} }
            Release = [pscustomobject]@{ channel='stable' }
            Artifact = [pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false }
        }
        $script:provider = [pscustomobject]@{ PluginId='Wintainium.provider.valid-fixture'; PluginType='Provider' }
        $script:installer = [pscustomobject]@{ PluginId='Wintainium.installer.valid-fixture'; PluginType='Installer' }
        $script:reconciliation = [pscustomobject]@{ PluginId='Wintainium.reconciliation.valid-fixture'; PluginType='Reconciliation' }
        $script:release = [pscustomobject]@{
            OperationId=$script:operationId
            IsSuccessful=$true
            Status='DiscoveryCompleted'
            Releases=@([pscustomobject]@{
                ReleaseId='release-2'; Version='2.0.0'; Channel='stable'; Deprecated=$false
                Artifacts=@([pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64'; Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('a'*64) }) })
            })
            Errors=@(); Warnings=@(); LogEvents=@()
        }
        $script:decision = [pscustomobject]@{ OperationId=$script:operationId; Status='UpdateAvailable'; IsUpdateAvailable=$true; SelectedRelease=$script:release.Releases[0]; SelectedArtifact=$script:release.Releases[0].Artifacts[0] }
        }
    }

    It 'blocks update execution when provider discovery fails' {
        InModuleScope Wintainium.Core {
            Mock Test-WintainiumApplicationDefinition {
                param($ManifestPath, $PluginRoot, $SchemaPath, $OperationId)
                [pscustomobject]@{
                    OperationId=$OperationId
                    IsValid=$true
                    Manifest=$script:manifest
                    ProviderPlugin=$script:provider
                    InstallerPlugin=$script:installer
                    ReconciliationPlugin=$script:reconciliation
                    Errors=@()
                    Warnings=@()
                    LogEvents=@()
                }
            }
            Mock Invoke-WintainiumProviderOperation {
                param($Provider, $Request)
                [pscustomobject]@{
                    OperationId=$Request.OperationId
                    IsSuccessful=$false
                    Status='DiscoveryFailed'
                    Errors=@([pscustomobject]@{ Code='ProviderDiscoveryFailed'; Message='Provider fixture failure.' })
                    Warnings=@()
                    LogEvents=@()
                }
            }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath 'C:\Wintainium\example.json' -StateRoot 'C:\Wintainium\state' -MachineArchitecture x64 -DownloadRoot 'C:\Wintainium\downloads'

            $result.IsSuccessful | Should -BeFalse
            $result.State.Status | Should -Be 'Failed'
            $result.State.FailedStage.Name | Should -Be 'ReleaseDiscovery'
            @($result.StageResults).Count | Should -Be 2
            $result.StageResults[-1].Execution.Result.Status | Should -Be 'DiscoveryFailed'
            $result.StageResults[-1].Execution.Result.IsSuccessful | Should -BeFalse
            Should -Invoke Invoke-WintainiumProviderOperation -Times 1 -Exactly        }
    }

    It 'blocks verification, installation, and reconciliation when download fails' {
        InModuleScope Wintainium.Core {
            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$script:operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$script:operationId; IsValid=$true; Manifest=$script:manifest; ProviderPlugin=$script:provider; InstallerPlugin=$script:installer; ReconciliationPlugin=$script:reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $script:release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' } }
            Mock Get-WintainiumUpdateDecision { $script:decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$script:operationId; UpdateDecision=$script:decision; SelectedRelease=$script:decision.SelectedRelease; SelectedArtifact=$script:decision.SelectedArtifact } }
            Mock Invoke-WintainiumDownload {
                [pscustomobject]@{
                    OperationId=$script:operationId; IsSuccessful=$false; Status='Failed'
                    FailureKind='DownloadFailed'; ErrorMessage='Download fixture failure.'
                }
            }
            Mock Invoke-WintainiumArtifactVerification { throw 'verification must not execute after download failure' }
            Mock Select-WintainiumInstaller { throw 'installer selection must not execute after download failure' }
            Mock Invoke-WintainiumInstallerOperation { throw 'installer must not execute after download failure' }
            Mock Invoke-WintainiumReconciliationOperation { throw 'reconciliation must not execute after download failure' }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeFalse
            $result.State.Status | Should -Be 'Failed'
            $result.State.FailedStage.Name | Should -Be 'Download'
            @($result.StageResults).Count | Should -Be 4
            $result.StageResults[-1].Execution.Result.Status | Should -Be 'Failed'
            $result.StageResults[-1].Execution.Result.FailureKind | Should -Be 'DownloadFailed'
            Should -Invoke Invoke-WintainiumProviderOperation -Times 1 -Exactly
            Should -Invoke New-WintainiumDownloadRequest -Times 1 -Exactly -ParameterFilter { $OperationId -eq $script:operationId }
            Should -Invoke Invoke-WintainiumDownload -Times 1 -Exactly
            Should -Invoke Invoke-WintainiumArtifactVerification -Times 0 -Exactly
            Should -Invoke Select-WintainiumInstaller -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumInstallerOperation -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 0 -Exactly        }
    }


    It 'blocks reconciliation when installation fails' {
        InModuleScope Wintainium.Core {
            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$script:operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$script:operationId; IsValid=$true; Manifest=$script:manifest; ProviderPlugin=$script:provider; InstallerPlugin=$script:installer; ReconciliationPlugin=$script:reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $script:release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' } }
            Mock Get-WintainiumUpdateDecision { $script:decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$script:operationId; UpdateDecision=$script:decision; SelectedRelease=$script:decision.SelectedRelease; SelectedArtifact=$script:decision.SelectedArtifact } }
            Mock Invoke-WintainiumDownload { [pscustomobject]@{ OperationId=$script:operationId; Status='Downloaded'; DestinationPath='/tmp/app.exe' } }
            Mock Invoke-WintainiumArtifactVerification { [pscustomobject]@{ OperationId=$script:operationId; IsSuccessful=$true; Status='Verified'; Algorithm='SHA256'; ExpectedHash=('a'*64); ActualHash=('a'*64); DestinationPath='/tmp/app.exe' } }
            Mock Select-WintainiumInstaller { [pscustomobject]@{ IsSelected=$true; InstallerPlugin=$script:installer; ArtifactFormat='exe' } }
            Mock New-WintainiumInstallerRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$script:operationId; DownloadOperationId=$script:operationId; Manifest=$script:manifest; Installer=$script:installer; Artifact=[pscustomobject]@{ Path='/tmp/app.exe'; Uri='https://example.test/app.exe'; FileName='app.exe' } }; Errors=@() } }
            Mock New-WintainiumInstallerInvocation { [pscustomobject]@{ IsValid=$true; Invocation=[pscustomobject]@{ OperationId=$script:operationId; DownloadOperationId=$script:operationId; PluginId=$script:installer.PluginId; PluginModulePath='/tmp/installer.psm1'; ArtifactPath='/tmp/app.exe'; ArtifactFormat='exe'; Settings=@{} }; Error=$null } }
            Mock Invoke-WintainiumInstallerOperation {
                [pscustomobject]@{
                    OperationId=$script:operationId
                    IsSuccessful=$false
                    Status='Failed'
                    FailureKind='InstallerFailed'
                    ErrorMessage='Installer fixture failure.'
                }
            }
            Mock Invoke-WintainiumReconciliationOperation { throw 'reconciliation must not execute after installation failure' }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation { throw 'authoritative state must not execute after installation failure' }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeFalse
            $result.State.Status | Should -Be 'Failed'
            $result.State.FailedStage.Name | Should -Be 'Installation'
            $result.OperationId | Should -Be $script:operationId
            @($result.StageResults).Count | Should -Be 7
            $result.StageResults[-1].Execution.Result.FailureKind | Should -Be 'InstallerFailed'
            Should -Invoke Invoke-WintainiumInstallerOperation -Times 1 -Exactly -ParameterFilter { $Invocation.OperationId -eq $script:operationId }
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 0 -Exactly
        }
    }

    It 'blocks authoritative state reconciliation when post-install reconciliation fails' {
        InModuleScope Wintainium.Core {
            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$script:operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$script:operationId; IsValid=$true; Manifest=$script:manifest; ProviderPlugin=$script:provider; InstallerPlugin=$script:installer; ReconciliationPlugin=$script:reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $script:release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' } }
            Mock Get-WintainiumUpdateDecision { $script:decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$script:operationId; UpdateDecision=$script:decision; SelectedRelease=$script:decision.SelectedRelease; SelectedArtifact=$script:decision.SelectedArtifact } }
            Mock Invoke-WintainiumDownload { [pscustomobject]@{ OperationId=$script:operationId; Status='Downloaded'; DestinationPath='/tmp/app.exe' } }
            Mock Invoke-WintainiumArtifactVerification { [pscustomobject]@{ OperationId=$script:operationId; IsSuccessful=$true; Status='Verified'; Algorithm='SHA256'; ExpectedHash=('a'*64); ActualHash=('a'*64); DestinationPath='/tmp/app.exe' } }
            Mock Select-WintainiumInstaller { [pscustomobject]@{ IsSelected=$true; InstallerPlugin=$script:installer; ArtifactFormat='exe' } }
            Mock New-WintainiumInstallerRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$script:operationId; DownloadOperationId=$script:operationId; Manifest=$script:manifest; Installer=$script:installer; Artifact=[pscustomobject]@{ Path='/tmp/app.exe'; Uri='https://example.test/app.exe'; FileName='app.exe' } }; Errors=@() } }
            Mock New-WintainiumInstallerInvocation { [pscustomobject]@{ IsValid=$true; Invocation=[pscustomobject]@{ OperationId=$script:operationId; DownloadOperationId=$script:operationId; PluginId=$script:installer.PluginId; PluginModulePath='/tmp/installer.psm1'; ArtifactPath='/tmp/app.exe'; ArtifactFormat='exe'; Settings=@{} }; Error=$null } }
            Mock Invoke-WintainiumInstallerOperation { [pscustomobject]@{ OperationId=$script:operationId; IsSuccessful=$true; Status='Completed'; ExitCode=0 } }
            Mock Invoke-WintainiumReconciliationOperation {
                [pscustomobject]@{
                    OperationId=$script:operationId
                    IsSuccessful=$false
                    Status='Failed'
                    FailureKind='ReconciliationFailed'
                    Errors=@([pscustomobject]@{ Code='ReconciliationFailed'; Message='Reconciliation fixture failure.' })
                    Warnings=@()
                    LogEvents=@()
                }
            }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation { throw 'authoritative state must not execute after reconciliation failure' }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeFalse
            $result.State.Status | Should -Be 'Failed'
            $result.State.FailedStage.Name | Should -Be 'Reconciliation'
            $result.OperationId | Should -Be $script:operationId
            @($result.StageResults).Count | Should -Be 8
            $result.StageResults[-1].Execution.Result.FailureKind | Should -Be 'ReconciliationFailed'
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 1 -Exactly -ParameterFilter { $ReconciliationPlugin.PluginId -eq $script:reconciliation.PluginId -and $Request.OperationId -eq $script:operationId }
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 0 -Exactly
        }
    }

    It 'stops the lifecycle before any stage when cancellation is already requested' {
        InModuleScope Wintainium.Core {
            $source = [System.Threading.CancellationTokenSource]::new()
            try {
                $source.Cancel()
                Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$script:operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
                Mock Test-WintainiumApplicationDefinition { throw 'manifest validation must not execute after cancellation' }

                $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads' -CancellationToken $source.Token

                $result.IsSuccessful | Should -BeFalse
                $result.WasCancelled | Should -BeTrue
                $result.OperationId | Should -Be $script:operationId
                $result.State.Status | Should -Be 'Pending'
                @($result.StageResults).Count | Should -Be 0
                $result.Error.Code | Should -Be 'OrchestrationWorkflowCancelled'
                Should -Invoke Test-WintainiumApplicationDefinition -Times 0 -Exactly
            }
            finally {
                $source.Dispose()
            }
        }
    }

}
