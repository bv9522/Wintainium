$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium application lifecycle authoritative state integration' {
    It 'persists authoritative installed evidence after a successful update lifecycle' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{ Id='example.app' }
            $reconciliation = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Reconciled'; Evidence=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='2.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example'; EvidenceSource='Fixture' } }
            $lifecycleResult = [pscustomobject]@{
                IsSuccessful=$true; OperationId=$operationId; State=[pscustomobject]@{ Status='Completed' }
                StageResults=@(
                    [pscustomobject]@{ StageName='ManifestValidation'; Execution=[pscustomobject]@{ Result=[pscustomobject]@{ Manifest=$manifest } } }
                    [pscustomobject]@{ StageName='UpdateDecision'; Execution=[pscustomobject]@{ Result=[pscustomobject]@{ Status='UpdateAvailable'; IsUpdateAvailable=$true } } }
                    [pscustomobject]@{ StageName='Reconciliation'; Execution=[pscustomobject]@{ Result=$reconciliation } }
                )
            }
            $priorState = [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0' }
            $authoritative = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Persisted'; State=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='2.0.0' }; Persisted=$true; ReasonCode='AuthoritativeEvidencePersisted' }
            $script:WintainiumOriginalApplicationUpdateLifecycle = { param($ManifestPath,$StateRoot,$MachineArchitecture,$DownloadRoot,$PluginRoot,$SchemaPath,$InstallerTimeoutMilliseconds,$HttpClient,$CancellationToken) $lifecycleResult }
            Mock Get-WintainiumInstalledApplicationState { $priorState }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation { $authoritative }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeTrue
            $result.OperationId | Should -Be $operationId
            $result.StageResults[-1].Execution.Result.AuthoritativeStateResult.Status | Should -Be 'Persisted'
            Should -Invoke Get-WintainiumInstalledApplicationState -Times 1 -Exactly -ParameterFilter { $ApplicationId -eq 'example.app' }
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 1 -Exactly -ParameterFilter { $OperationId -eq $operationId -and $ApplicationId -eq 'example.app' -and $ReconciliationResult.OperationId -eq $operationId -and $PriorState.Version -eq '1.0.0' }
        }
    }

    It 'preserves a successful lifecycle when reconciliation reports Unknown evidence' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{ Id='example.app' }
            $reconciliation = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Reconciled'; Evidence=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Unknown'; EvidenceSource='Fixture' } }
            $lifecycleResult = [pscustomobject]@{ IsSuccessful=$true; OperationId=$operationId; State=[pscustomobject]@{ Status='Completed' }; StageResults=@(
                [pscustomobject]@{ StageName='ManifestValidation'; Execution=[pscustomobject]@{ Result=[pscustomobject]@{ Manifest=$manifest } } }
                [pscustomobject]@{ StageName='UpdateDecision'; Execution=[pscustomobject]@{ Result=[pscustomobject]@{ Status='UpdateAvailable'; IsUpdateAvailable=$true } } }
                [pscustomobject]@{ StageName='Reconciliation'; Execution=[pscustomobject]@{ Result=$reconciliation } }
            ) }
            $authoritative = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Preserved'; State=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0' }; Persisted=$false; ReasonCode='UnknownEvidencePreserved' }
            $script:WintainiumOriginalApplicationUpdateLifecycle = { param($ManifestPath,$StateRoot,$MachineArchitecture,$DownloadRoot,$PluginRoot,$SchemaPath,$InstallerTimeoutMilliseconds,$HttpClient,$CancellationToken) $lifecycleResult }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0' } }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation { $authoritative }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeTrue
            $result.StageResults[-1].Execution.Result.AuthoritativeStateResult.Status | Should -Be 'Preserved'
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 1 -Exactly
        }
    }

    It 'turns authoritative persistence failure into a failed reconciliation lifecycle result' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{ Id='example.app' }
            $reconciliation = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Reconciled'; Evidence=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='2.0.0'; EvidenceSource='Fixture' } }
            $lifecycleResult = [pscustomobject]@{ IsSuccessful=$true; OperationId=$operationId; State=[pscustomobject]@{ Status='Completed' }; StageResults=@(
                [pscustomobject]@{ StageName='ManifestValidation'; Execution=[pscustomobject]@{ Result=[pscustomobject]@{ Manifest=$manifest } } }
                [pscustomobject]@{ StageName='UpdateDecision'; Execution=[pscustomobject]@{ Result=[pscustomobject]@{ Status='UpdateAvailable'; IsUpdateAvailable=$true } } }
                [pscustomobject]@{ StageName='Reconciliation'; Execution=[pscustomobject]@{ Result=$reconciliation } }
            ) }
            $authoritative = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$false; Status='Failed'; Persisted=$false; ReasonCode='InstalledStatePersistenceFailed' }
            $script:WintainiumOriginalApplicationUpdateLifecycle = { param($ManifestPath,$StateRoot,$MachineArchitecture,$DownloadRoot,$PluginRoot,$SchemaPath,$InstallerTimeoutMilliseconds,$HttpClient,$CancellationToken) $lifecycleResult }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0' } }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation { $authoritative }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeFalse
            $result.Error.Code | Should -Be 'AuthoritativeStateReconciliationFailed'
            $result.State.Status | Should -Be 'Failed'
            $result.State.FailedStage.Name | Should -Be 'Reconciliation'
            $result.StageResults[-1].Execution.Result.AuthoritativeStateResult.ReasonCode | Should -Be 'InstalledStatePersistenceFailed'
        }
    }

    It 'does not reconcile or persist state for a no-update lifecycle' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{ Id='example.app' }
            $lifecycleResult = [pscustomobject]@{ IsSuccessful=$true; OperationId=$operationId; State=[pscustomobject]@{ Status='Completed' }; StageResults=@(
                [pscustomobject]@{ StageName='ManifestValidation'; Execution=[pscustomobject]@{ Result=[pscustomobject]@{ Manifest=$manifest } } }
                [pscustomobject]@{ StageName='UpdateDecision'; Execution=[pscustomobject]@{ Result=[pscustomobject]@{ Status='NoUpdateAvailable'; IsUpdateAvailable=$false } } }
                [pscustomobject]@{ StageName='Reconciliation'; Execution=[pscustomobject]@{ Result=[pscustomobject]@{ Status='Skipped'; IsSuccessful=$true } } }
            ) }
            $script:WintainiumOriginalApplicationUpdateLifecycle = { param($ManifestPath,$StateRoot,$MachineArchitecture,$DownloadRoot,$PluginRoot,$SchemaPath,$InstallerTimeoutMilliseconds,$HttpClient,$CancellationToken) $lifecycleResult }
            Mock Get-WintainiumInstalledApplicationState { throw 'should not execute' }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation { throw 'should not execute' }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeTrue
            Should -Invoke Get-WintainiumInstalledApplicationState -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 0 -Exactly
        }
    }
}
