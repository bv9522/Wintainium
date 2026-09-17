BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium application update lifecycle composition' {
    It 'executes the complete update path through reconciliation with one OperationId' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{ Id='example.app'; Source=[pscustomobject]@{ pluginId='provider'; requiredContractVersion='1'; settings=@{} }; Installer=[pscustomobject]@{ pluginId='installer'; requiredContractVersion='1'; settings=@{} }; Reconciliation=[pscustomobject]@{ pluginId='reconciliation'; requiredContractVersion='1'; settings=@{} }; Release=[pscustomobject]@{ channel='stable' }; Artifact=[pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false } }
            $provider = [pscustomobject]@{ PluginId='provider'; PluginType='Provider' }
            $installer = [pscustomobject]@{ PluginId='installer'; PluginType='Installer'; Capabilities=[ordered]@{ supportedFormats=@('exe') } }
            $reconciliation = [pscustomobject]@{ PluginId='reconciliation'; PluginType='Reconciliation' }
            $artifact = [pscustomobject]@{ format='exe' }
            $release = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='DiscoveryCompleted'; Releases=@([pscustomobject]@{ Version='2.0.0'; Channel='stable'; Artifacts=@($artifact) }); Errors=@(); Warnings=@(); LogEvents=@() }
            $decision = [pscustomobject]@{ OperationId=$operationId; Status='UpdateAvailable'; IsUpdateAvailable=$true; SelectedRelease=$release.Releases[0]; SelectedArtifact=$artifact }
            $download = [pscustomobject]@{ OperationId=$operationId; Status='Downloaded'; Uri='https://example.test/app.exe'; FileName='app.exe'; DestinationPath='/tmp/app.exe' }
            $verification = [pscustomobject]@{ OperationId=$operationId; Status='Verified'; Algorithm='SHA256'; ExpectedHash='abc'; ActualHash='abc'; DestinationPath='/tmp/app.exe' }
            $selection = [pscustomobject]@{ IsSelected=$true; InstallerPlugin=$installer; ArtifactFormat='exe'; Error=$null }
            $installation = [pscustomobject]@{ OperationId=$operationId; Status='Completed'; IsSuccessful=$true }
            $reconciliationResult = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Reconciled'; Evidence=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='2.0.0'; VersionSource='Reconciliation'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example'; EvidenceSource='fixture' } }

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$operationId; IsValid=$true; Manifest=$manifest; ProviderPlugin=$provider; InstallerPlugin=$installer; ReconciliationPlugin=$reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' } }
            Mock Get-WintainiumUpdateDecision { $decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$operationId } }
            Mock Invoke-WintainiumDownload { $download }
            Mock Invoke-WintainiumArtifactVerification { $verification }
            Mock Select-WintainiumInstaller { $selection }
            Mock New-WintainiumInstallerRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId } } }
            Mock New-WintainiumInstallerInvocation { [pscustomobject]@{ IsValid=$true; Invocation=[pscustomobject]@{} } }
            Mock Invoke-WintainiumInstallerOperation { $installation }
            Mock Invoke-WintainiumReconciliationOperation { $reconciliationResult }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

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

    It 'completes a no-update decision without downloading, verifying, installing, or reconciling' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{ Id='example.app'; Source=[pscustomobject]@{ pluginId='provider'; requiredContractVersion='1'; settings=@{} }; Installer=[pscustomobject]@{ pluginId='installer'; requiredContractVersion='1'; settings=@{} }; Reconciliation=[pscustomobject]@{ pluginId='reconciliation'; requiredContractVersion='1'; settings=@{} }; Release=[pscustomobject]@{ channel='stable' }; Artifact=[pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false } }
            $provider = [pscustomobject]@{ PluginId='provider'; PluginType='Provider' }
            $installer = [pscustomobject]@{ PluginId='installer'; PluginType='Installer' }
            $reconciliation = [pscustomobject]@{ PluginId='reconciliation'; PluginType='Reconciliation' }
            $release = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='DiscoveryCompleted'; Releases=@(); Errors=@(); Warnings=@(); LogEvents=@() }
            $decision = [pscustomobject]@{ OperationId=$operationId; Status='NoUpdateAvailable'; IsUpdateAvailable=$false; SelectedRelease=$null; SelectedArtifact=$null }

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$operationId; IsValid=$true; Manifest=$manifest; ProviderPlugin=$provider; InstallerPlugin=$installer; ReconciliationPlugin=$reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' } }
            Mock Get-WintainiumUpdateDecision { $decision }
            Mock Invoke-WintainiumDownload { throw 'should not execute' }
            Mock Invoke-WintainiumArtifactVerification { throw 'should not execute' }
            Mock Select-WintainiumInstaller { throw 'should not execute' }
            Mock Invoke-WintainiumInstallerOperation { throw 'should not execute' }
            Mock Invoke-WintainiumReconciliationOperation { throw 'should not execute' }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

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
            $result.State.Status | Should -Be 'Completed'
            @($result.StageResults).Count | Should -Be 8
            @($result.StageResults | Where-Object { $null -ne $_.Execution -and $null -ne $_.Execution.Result -and $null -ne $_.Execution.Result.PSObject.Properties['Status'] -and $_.Execution.Result.Status -eq 'Skipped' }).Count | Should -Be 5
            Should -Invoke Invoke-WintainiumDownload -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumArtifactVerification -Times 0 -Exactly
            Should -Invoke Select-WintainiumInstaller -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumInstallerOperation -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 0 -Exactly
a        }
    }
}
