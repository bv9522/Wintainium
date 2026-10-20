$testRoot = Split-Path -Path (Split-Path -Parent $PSScriptRoot) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

Import-Module $modulePath -Force

Describe 'Wintainium public application reconciliation command' {
    It 'coordinates validation, reconciliation, and authoritative persistence' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{ Id='org.example.app' }
            $plugin = [pscustomobject]@{ PluginId='Wintainium.reconciliation.fixture'; PluginType='Reconciliation' }
            $prior = New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Unknown
            $evidence = [pscustomobject]@{
                ApplicationId='org.example.app'; InstallationState='Installed'
                EvidenceSource='Fixture'; Version='2.0.0'; VersionSource='Observed'
            }
            Mock Test-WintainiumApplicationDefinition {
                [pscustomobject]@{
                    OperationId=$operationId; IsValid=$true; Manifest=$manifest
                    ReconciliationPlugin=$plugin; Errors=@(); Warnings=@(); LogEvents=@()
                }
            }
            Mock Get-WintainiumInstalledApplicationState { $prior }
            Mock Invoke-WintainiumReconciliationOperation {
                [pscustomobject]@{
                    OperationId=$operationId; IsSuccessful=$true; Status='Reconciled'
                    Evidence=$evidence; Errors=@(); Warnings=@(); LogEvents=@()
                }
            }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation {
                [pscustomobject]@{
                    OperationId=$operationId; IsSuccessful=$true; Status='Persisted'
                    State=(New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Installed -Version '2.0.0' -VersionSource 'Observed')
                    Persisted=$true; ReasonCode='AuthoritativeEvidencePersisted'; Warnings=@()
                }
            }

            $result = Invoke-WintainiumApplicationReconciliation -ManifestPath 'C:\manifest.json' -StateRoot 'C:\state' -OperationId $operationId

            $result.IsSuccessful | Should -BeTrue
            $result.Status | Should -Be 'Persisted'
            $result.ApplicationId | Should -Be 'org.example.app'
            $result.State.InstallationState | Should -Be 'Installed'
            $result.State.Version | Should -Be '2.0.0'
            $result.ReasonCode | Should -Be 'AuthoritativeEvidencePersisted'
            @($result.LogEvents | Where-Object EventName -eq 'AuthoritativeEvidencePersisted').Count | Should -Be 1
            Should -Invoke Test-WintainiumApplicationDefinition -Times 1 -Exactly
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 1 -Exactly
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 1 -Exactly
        }
    }

    It 'does not persist or invent state when manifest validation fails' {
        InModuleScope Wintainium.Core {
            Mock Test-WintainiumApplicationDefinition {
                [pscustomobject]@{
                    OperationId='bad-op'; IsValid=$false; Manifest=$null
                    ReconciliationPlugin=$null
                    Errors=@([pscustomobject]@{Code='ApplicationDefinitionInvalid';Message='invalid'})
                    Warnings=@(); LogEvents=@()
                }
            }
            Mock Invoke-WintainiumReconciliationOperation
            Mock Invoke-WintainiumAuthoritativeStateReconciliation

            $result = Invoke-WintainiumApplicationReconciliation -ManifestPath 'C:\manifest.json' -StateRoot 'C:\state'

            $result.IsSuccessful | Should -BeFalse
            $result.Status | Should -Be 'ApplicationDefinitionInvalid'
            $result.State | Should -BeNullOrEmpty
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumAuthoritativeStateReconciliation -Times 0 -Exactly
        }
    }
    It 'propagates the authoritative Unknown-preservation reason and warning' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{ Id='org.example.unknown' }
            $plugin = [pscustomobject]@{ PluginId='Wintainium.reconciliation.fixture'; PluginType='Reconciliation' }
            $prior = New-WintainiumInstalledApplicationState -ApplicationId 'org.example.unknown' -InstallationState Installed -Version '1.0'
            $warning = [pscustomobject]@{
                Code='UnknownEvidencePreserved'
                Path='$.Evidence.InstallationState'
                Message='Reconciliation returned Unknown; prior state was preserved.'
            }
            Mock Test-WintainiumApplicationDefinition {
                [pscustomobject]@{
                    OperationId=$operationId; IsValid=$true; Manifest=$manifest
                    ReconciliationPlugin=$plugin; Errors=@(); Warnings=@(); LogEvents=@()
                }
            }
            Mock Get-WintainiumInstalledApplicationState { $prior }
            Mock Invoke-WintainiumReconciliationOperation {
                [pscustomobject]@{
                    OperationId=$operationId; IsSuccessful=$true; Status='Reconciled'
                    Evidence=[pscustomobject]@{
                        ApplicationId='org.example.unknown'; InstallationState='Unknown'; EvidenceSource='Fixture'
                    }
                    Errors=@(); Warnings=@(); LogEvents=@()
                }
            }
            Mock Invoke-WintainiumAuthoritativeStateReconciliation {
                [pscustomobject]@{
                    OperationId=$operationId; IsSuccessful=$true; Status='Preserved'
                    State=$prior; Persisted=$false; ReasonCode='UnknownEvidencePreserved'
                    Errors=@(); Warnings=@($warning)
                }
            }

            $result = Invoke-WintainiumApplicationReconciliation -ManifestPath 'C:\manifest.json' -StateRoot 'C:\state' -OperationId $operationId

            $result.IsSuccessful | Should -BeTrue
            $result.Status | Should -Be 'Preserved'
            $result.ReasonCode | Should -Be 'UnknownEvidencePreserved'
            $result.State.InstallationState | Should -Be 'Installed'
            @($result.Warnings | Where-Object Code -eq 'UnknownEvidencePreserved').Count | Should -Be 1
            @($result.LogEvents | Where-Object EventName -eq 'UnknownEvidencePreserved').Count | Should -Be 1
            $event = @($result.LogEvents | Where-Object EventName -eq 'UnknownEvidencePreserved')[0]
            $event.Context.PriorInstallationState | Should -Be 'Installed'
            $event.Context.ObservedInstallationState | Should -Be 'Unknown'
        }
    }

}
