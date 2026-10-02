$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium live download failure diagnostic boundary' {
    It 'preserves a structured Download failure through the real orchestration boundary' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{
                Id='example.app'
                Source=[pscustomobject]@{ pluginId='provider'; requiredContractVersion='1'; settings=@{} }
                Installer=[pscustomobject]@{ pluginId='installer'; requiredContractVersion='1'; settings=@{} }
                Reconciliation=[pscustomobject]@{ pluginId='reconciliation'; requiredContractVersion='1'; settings=@{} }
                Release=[pscustomobject]@{ channel='stable' }
                Artifact=[pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false }
            }
            $provider=[pscustomobject]@{ PluginId='provider'; PluginType='Provider' }
            $installer=[pscustomobject]@{ PluginId='installer'; PluginType='Installer' }
            $reconciliation=[pscustomobject]@{ PluginId='reconciliation'; PluginType='Reconciliation' }
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
            $downloadFailure=[pscustomobject][ordered]@{
                OperationId=$operationId
                Status='Failed'
                FailureKind='DestinationExists'
                ErrorMessage='The destination file already exists.'
                Retryable=$false
                Uri=$decision.SelectedArtifact.Uri
                FileName='app.exe'
                DestinationPath='/tmp/downloads/app.exe'
                BytesWritten=0
            }

            Mock New-WintainiumOrchestrationRequest {
                [pscustomobject]@{
                    IsValid=$true
                    Request=[pscustomobject]@{
                        OperationId=$operationId
                        ManifestPath='/tmp/example.json'
                        MachineArchitecture='x64'
                        DownloadRoot='/tmp/downloads'
                    }
                    Errors=@()
                }
            }
            Mock Get-WintainiumEnvironment { [pscustomobject]@{ MachineArchitecture='x64' } }
            Mock Test-WintainiumApplicationDefinition {
                [pscustomobject]@{
                    OperationId=$operationId
                    IsValid=$true
                    Manifest=$manifest
                    ProviderPlugin=$provider
                    InstallerPlugin=$installer
                    ReconciliationPlugin=$reconciliation
                    Errors=@()
                    Warnings=@()
                    LogEvents=@()
                }
            }
            Mock Invoke-WintainiumProviderOperation { $release }
            Mock Get-WintainiumInstalledApplicationState {
                [pscustomobject]@{
                    ApplicationId='example.app'
                    InstallationState='Installed'
                    Version='1.0.0'
                    VersionSource='Fixture'
                    Architecture='x64'
                    Channel='stable'
                    InstallationLocation='/opt/example'
                }
            }
            Mock Get-WintainiumUpdateDecision { $decision }
            Mock New-WintainiumDownloadRequest {
                [pscustomobject]@{
                    OperationId=$operationId
                    UpdateDecision=$decision
                    SelectedRelease=$decision.SelectedRelease
                    SelectedArtifact=$decision.SelectedArtifact
                }
            }
            Mock Invoke-WintainiumDownload { $downloadFailure }
            Mock Invoke-WintainiumDownloadArtifactCleanup {
                [pscustomobject]@{
                    IsSuccessful=$true
                    Status='Retained'
                    Outcome='Failed'
                    Removed=$false
                    Retained=$true
                }
            }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture 'x64' -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeFalse
            $result.Error.Code | Should -Be 'OrchestrationStageExecutionFailed'
            $result.Error.Message | Should -Be 'The destination file already exists.'

            $downloadStage = @($result.StageResults | Where-Object { $_.StageName -eq 'Download' })[0]
            $downloadStage.Execution.IsSuccessful | Should -BeFalse
            $downloadStage.Execution.Error.Code | Should -Be 'OrchestrationStageStructuredFailure'
            $downloadStage.Execution.Error.FailureKind | Should -Be 'DestinationExists'
            $downloadStage.Execution.Error.ErrorMessage | Should -Be 'The destination file already exists.'
            $downloadStage.Execution.Error.Detail.FailureKind | Should -Be 'DestinationExists'
            $downloadStage.Execution.Error.Detail.ErrorMessage | Should -Be 'The destination file already exists.'
            $downloadStage.Execution.Result.FailureKind | Should -Be 'DestinationExists'
            $downloadStage.Execution.Result.ErrorMessage | Should -Be 'The destination file already exists.'
        }
    }

    It 'projects the same structured Download failure into the public update contract' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $downloadResult = [pscustomobject]@{
                OperationId=$operationId
                IsSuccessful=$false
                Status='Failed'
                FailureKind='DestinationExists'
                ErrorMessage='The destination file already exists.'
                Retryable=$false
            }
            $stageOperation = [pscustomobject]@{
                IsSuccessful=$false
                OperationId=$operationId
                StageSequence=4
                StageName='Download'
                Execution=[pscustomobject]@{
                    IsSuccessful=$false
                    WasCancelled=$false
                    OperationId=$operationId
                    StageSequence=4
                    StageName='Download'
                    Result=$downloadResult
                    Error=[pscustomobject]@{
                        Code='OrchestrationStageStructuredFailure'
                        Message='The destination file already exists.'
                        StageStatus='Failed'
                        FailureKind='DestinationExists'
                        ErrorMessage='The destination file already exists.'
                        Detail=$downloadResult
                    }
                }
                State=[pscustomobject]@{ Status='Failed' }
                Error=[pscustomobject]@{
                    Code='OrchestrationStageExecutionFailed'
                    Message='The destination file already exists.'
                }
            }
            $lifecycle=[pscustomobject]@{
                IsSuccessful=$false
                WasCancelled=$false
                OperationId=$operationId
                State=[pscustomobject]@{ Status='Failed' }
                StageResults=@($stageOperation)
                Error=$stageOperation.Error
            }

            $public = ConvertTo-WintainiumPublicApplicationUpdateResult -LifecycleResult $lifecycle

            $public.IsSuccessful | Should -BeFalse
            $public.Status | Should -Be 'Failed'
            $public.Stages[0].Sequence | Should -Be 4
            $public.Stages[0].Name | Should -Be 'Download'
            $public.Stages[0].Error.Code | Should -Be 'DestinationExists'
            $public.Stages[0].Error.Message | Should -Be 'The destination file already exists.'
            @($public.Errors | Where-Object { $_.Code -eq 'DestinationExists' }).Count | Should -Be 1
        }
    }
}
