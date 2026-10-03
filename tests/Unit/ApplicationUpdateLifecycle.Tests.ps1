$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium application update lifecycle composition' {
    It 'executes the complete update path through reconciliation with one OperationId' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{
                Id = 'example.app'
                Source = [pscustomobject]@{ pluginId='Wintainium.provider.valid-fixture'; requiredContractVersion='1'; settings=@{} }
                Installer = [pscustomobject]@{ pluginId='Wintainium.installer.valid-fixture'; requiredContractVersion='1'; settings=@{} }
                Reconciliation = [pscustomobject]@{ pluginId='Wintainium.reconciliation.valid-fixture'; requiredContractVersion='1'; settings=@{} }
                Release = [pscustomobject]@{ channel='stable' }
                Artifact = [pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false }
            }
            $provider = [pscustomobject]@{ PluginId='Wintainium.provider.valid-fixture'; PluginType='Provider'; EntryPoint='provider.psm1'; DescriptorPath='/tmp/provider/plugin.json' }
            $installer = [pscustomobject]@{ PluginId='Wintainium.installer.valid-fixture'; PluginType='Installer'; EntryPoint='installer.psm1'; DescriptorPath='/tmp/installer/plugin.json' }
            $reconciliation = [pscustomobject]@{ PluginId='Wintainium.reconciliation.valid-fixture'; PluginType='Reconciliation'; EntryPoint='reconciliation.psm1'; DescriptorPath='/tmp/reconciliation/plugin.json' }
            $release = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='DiscoveryCompleted'; Releases=@([pscustomobject]@{ ReleaseId='release-2'; Version='2.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@([pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64'; Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('a'*64) }) }) }); Errors=@(); Warnings=@(); LogEvents=@() }
            $decision = [pscustomobject]@{ OperationId=$operationId; Status='UpdateAvailable'; IsUpdateAvailable=$true; SelectedRelease=$release.Releases[0]; SelectedArtifact=$release.Releases[0].Artifacts[0] }
            $download = [pscustomobject]@{ OperationId=$operationId; Status='Downloaded'; Uri='https://example.test/app.exe'; FileName='app.exe'; DestinationPath='/tmp/app.exe'; BytesWritten=10 }
            $verification = [pscustomobject]@{ OperationId=$operationId; Status='Verified'; Algorithm='SHA256'; ExpectedHash=('a'*64); ActualHash=('a'*64); DestinationPath='/tmp/app.exe' }
            $selection = [pscustomobject]@{ IsSelected=$true; InstallerPlugin=$installer; ArtifactFormat='exe' }
            $installation = [pscustomobject]@{ OperationId=$operationId; Status='Completed'; FailureKind=$null; ExitCode=0 }
            $reconciliationResult = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Reconciled'; Evidence=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='2.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example'; EvidenceSource='Fixture' }; Errors=@(); Warnings=@(); LogEvents=@() }

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$operationId; IsValid=$true; Manifest=$manifest; ProviderPlugin=$provider; InstallerPlugin=$installer; ReconciliationPlugin=$reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' } }
            Mock Get-WintainiumUpdateDecision { $decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$operationId; UpdateDecision=$decision; SelectedRelease=$decision.SelectedRelease; SelectedArtifact=$decision.SelectedArtifact } }
            Mock Invoke-WintainiumDownload { $download }
            Mock Invoke-WintainiumArtifactVerification { $verification }
            Mock Select-WintainiumInstaller { $selection }
            Mock New-WintainiumInstallerRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId; DownloadOperationId=$operationId; Manifest=$manifest; Installer=$manifest.Installer; Artifact=[pscustomobject]@{ Path='/tmp/app.exe'; Uri='https://example.test/app.exe'; FileName='app.exe' } }; Errors=@() } }
            Mock New-WintainiumInstallerInvocation { [pscustomobject]@{ IsValid=$true; Invocation=[pscustomobject]@{ OperationId=$operationId; DownloadOperationId=$operationId; PluginId=$installer.PluginId; PluginModulePath='/tmp/installer.psm1'; ArtifactPath='/tmp/app.exe'; ArtifactFormat='exe'; Settings=@{} }; Error=$null } }
            Mock Invoke-WintainiumInstallerOperation { $installation }
            Mock Invoke-WintainiumReconciliationOperation { $reconciliationResult }

            $result = Invoke-WintainiumApplicationLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            if (-not $result.IsSuccessful) {
                $failedStage = if ($null -ne $result.State -and $null -ne $result.State.FailedStage) { [string]$result.State.FailedStage.Name } else { '<none>' }
                $errorCode = if ($null -ne $result.Error) { [string]$result.Error.Code } else { '<none>' }
                $errorMessage = if ($null -ne $result.Error) { [string]$result.Error.Message } else { '<none>' }
                $stageDetail = '<none>'
                $failedResult = @($result.StageResults | Where-Object { [string]$_.StageName -eq $failedStage -or ($null -ne $_.PSObject.Properties['Execution'] -and [string]$_.Execution.StageName -eq $failedStage) } | Select-Object -Last 1)
                if ($failedResult.Count -gt 0) {
                    $failedOperation = $failedResult[0]
                    $execution = $failedOperation.Execution
                    if ($null -ne $execution -and $null -ne $execution.PSObject.Properties['Error'] -and $null -ne $execution.Error) { $stageDetail = ($execution.Error | Out-String).Trim() }
                    elseif ($null -ne $execution -and $null -ne $execution.PSObject.Properties['Result'] -and $null -ne $execution.Result) { $stageDetail = ($execution.Result | Out-String).Trim() }
                    elseif ($null -ne $execution) { $stageDetail = ($execution | Out-String).Trim() }
                }
                throw "Lifecycle failed. ErrorCode=$errorCode; ErrorMessage=$errorMessage; StateStatus=$($result.State.Status); FailedStage=$failedStage; FailedStageDetail=$stageDetail"
            }
            $result.IsSuccessful | Should -BeTrue
            $result.OperationId | Should -Be $operationId
            $result.State.Status | Should -Be 'Completed'
            @($result.StageResults).Count | Should -Be 8
            @($result.StageResults | Where-Object { $_.StageName -eq 'Reconciliation' }).Count | Should -Be 1
            $result.StageResults[-1].Execution.Result.Evidence.InstallationState | Should -Be 'Installed'
            Should -Invoke New-WintainiumDownloadRequest -Times 1 -Exactly -ParameterFilter { $OperationId -eq $operationId }
            Should -Invoke New-WintainiumInstallerRequest -Times 1 -Exactly -ParameterFilter { $OperationId -eq $operationId }
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 1 -Exactly -ParameterFilter { $Request.OperationId -eq $operationId }
        }
    }

    It 'completes a decision-indeterminate path without downloading, verifying, installing, or reconciling' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{ Id='example.app'; Source=[pscustomobject]@{ pluginId='provider'; requiredContractVersion='1'; settings=@{} }; Installer=[pscustomobject]@{ pluginId='installer'; requiredContractVersion='1'; settings=@{} }; Reconciliation=[pscustomobject]@{ pluginId='reconciliation'; requiredContractVersion='1'; settings=@{} }; Release=[pscustomobject]@{ channel='stable' }; Artifact=[pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false } }
            $provider = [pscustomobject]@{ PluginId='provider'; PluginType='Provider' }
            $installer = [pscustomobject]@{ PluginId='installer'; PluginType='Installer' }
            $reconciliation = [pscustomobject]@{ PluginId='reconciliation'; PluginType='Reconciliation' }
            $release = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='DiscoveryCompleted'; Releases=@(); Errors=@(); Warnings=@(); LogEvents=@() }
            $decision = [pscustomobject]@{ OperationId=$operationId; Status='DecisionIndeterminate'; IsUpdateAvailable=$false; SelectedRelease=$null; SelectedArtifact=$null }

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$operationId; IsValid=$true; Manifest=$manifest; ProviderPlugin=$provider; InstallerPlugin=$installer; ReconciliationPlugin=$reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $release }
            Mock Get-WintainiumInstalledApplicationState { New-WintainiumInstalledApplicationState -ApplicationId 'example.app' -InstallationState Unknown }
            Mock Get-WintainiumUpdateDecision { $decision }
            Mock Invoke-WintainiumDownload { throw 'should not execute' }
            Mock Invoke-WintainiumArtifactVerification { throw 'should not execute' }
            Mock Select-WintainiumInstaller { throw 'should not execute' }
            Mock Invoke-WintainiumInstallerOperation { throw 'should not execute' }
            Mock Invoke-WintainiumReconciliationOperation { throw 'should not execute' }

            $result = Invoke-WintainiumApplicationLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            if (-not $result.IsSuccessful) {
                $failedStage = if ($null -ne $result.State -and $null -ne $result.State.FailedStage) { [string]$result.State.FailedStage.Name } else { '<none>' }
                $errorCode = if ($null -ne $result.Error) { [string]$result.Error.Code } else { '<none>' }
                $errorMessage = if ($null -ne $result.Error) { [string]$result.Error.Message } else { '<none>' }
                $stateStatus = if ($null -ne $result.State) { [string]$result.State.Status } else { '<none>' }
                $stageSummary = @($result.StageResults | ForEach-Object {
                        $executionResult = if ($null -ne $_.Execution) { $_.Execution.Result } else { $null }
                        $status = if ($null -ne $executionResult -and $executionResult.PSObject.Properties['Status']) { [string]$executionResult.Status } else { '<none>' }
                        $successful = if ($null -ne $executionResult -and $executionResult.PSObject.Properties['IsSuccessful']) { [string]$executionResult.IsSuccessful } else { '<none>' }
                        "{0}:Status={1};IsSuccessful={2}" -f $_.StageName,$status,$successful
                    }) -join ' | '
                throw "Decision-indeterminate lifecycle failed. ErrorCode=$errorCode; ErrorMessage=$errorMessage; StateStatus=$stateStatus; FailedStage=$failedStage; Stages=$stageSummary"
            }

            $result.IsSuccessful | Should -BeTrue
            $result.State.Status | Should -Be 'Completed'
            @($result.StageResults).Count | Should -Be 8
            @($result.StageResults | Where-Object { $null -ne $_.Execution -and $null -ne $_.Execution.Result -and $null -ne $_.Execution.Result.PSObject.Properties['Status'] -and $_.Execution.Result.Status -eq 'Skipped' }).Count | Should -Be 5
            $installerStage = @($result.StageResults | Where-Object { $_.StageName -eq 'InstallerSelection' })[0]
            $installerStage.Execution.Result.OperationId | Should -Be $operationId
            Should -Invoke Invoke-WintainiumDownload -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumArtifactVerification -Times 0 -Exactly
            Should -Invoke Select-WintainiumInstaller -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumInstallerOperation -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 0 -Exactly
        }
    }

    It 'normalizes a download result without status as a failed stage instead of throwing' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $decision = [pscustomobject]@{
                OperationId=$operationId
                Status='UpdateAvailable'
                IsUpdateAvailable=$true
                SelectedRelease=[pscustomobject]@{ Version='2.0.0' }
                SelectedArtifact=[pscustomobject]@{ Uri='https://example.test/app.exe'; FileName='app.exe' }
            }
            $state = [pscustomobject]@{
                StageResults=@(
                    [pscustomobject]@{
                        Name='UpdateDecision'
                        Result=$decision
                    }
                )
            }
            $stage = [pscustomobject]@{ Name='Download'; Sequence=1 }
            $request = [pscustomobject]@{
                OperationId=$operationId
                ManifestPath='/tmp/example.json'
                MachineArchitecture='x64'
                DownloadRoot='/tmp/downloads'
            }
            $plan = [pscustomobject]@{
                OperationId=$operationId
                Stages=@($stage)
            }
            $context = [pscustomobject]@{
                OperationId=$operationId
                CancellationToken=[System.Threading.CancellationToken]::None
            }
            $malformedDownload = [pscustomobject]@{
                OperationId=$operationId
                Uri=$decision.SelectedArtifact.Uri
                FileName=$decision.SelectedArtifact.FileName
            }

            Mock New-WintainiumOrchestrationRequest {
                [pscustomobject]@{ IsValid=$true; Request=$request; Errors=@() }
            }
            Mock Get-WintainiumEnvironment {
                [pscustomobject]@{ MachineArchitecture='x64' }
            }
            Mock New-WintainiumOrchestrationStagePlan {
                [pscustomobject]@{ IsValid=$true; Plan=$plan; Errors=@() }
            }
            Mock Invoke-WintainiumOrchestrationWorkflow {
                param($OperationState,$StagePlan,$CancellationContext,$StageFactory)
                $binding = & $StageFactory $stage $state $context
                $stageExecution = @(& $binding.StageExecutor -StageInput $binding.StageInput -CancellationToken $context.CancellationToken)
                $execution = if ($stageExecution.Count -eq 1) { $stageExecution[0] } else { $stageExecution }
                [pscustomobject]@{
                    IsSuccessful=$false
                    WasCancelled=$false
                    State=$state
                    StageResults=@([pscustomobject]@{
                        StageName='Download'
                        Execution=[pscustomobject]@{
                            IsSuccessful=$execution.IsSuccessful
                            WasCancelled=$false
                            Result=$execution
                        }
                    })
                    Error=[pscustomobject]@{
                        Code='OrchestrationStageResultUnsuccessful'
                        Message='The Download stage returned an unsuccessful result.'
                    }
                }
            }
            Mock New-WintainiumDownloadRequest {
                [pscustomobject]@{
                    OperationId=$operationId
                    SelectedArtifact=$decision.SelectedArtifact
                }
            }
            Mock Invoke-WintainiumDownload {
                $malformedDownload
            }

            $result = Invoke-WintainiumApplicationLifecycle -ManifestPath $request.ManifestPath -StateRoot '/tmp/state' -MachineArchitecture $request.MachineArchitecture -DownloadRoot $request.DownloadRoot

            $result.IsSuccessful | Should -BeFalse
            $result.Error.Code | Should -Be 'OrchestrationStageResultUnsuccessful'
            $result.StageResults[0].Execution.IsSuccessful | Should -BeFalse
            $result.StageResults[0].Execution.PSObject.Properties['Result'] | Should -Not -BeNullOrEmpty
            $result.StageResults[0].Execution.Result.IsSuccessful | Should -BeFalse
            Should -Invoke Invoke-WintainiumDownload -Times 1 -Exactly
        }
    }
}
