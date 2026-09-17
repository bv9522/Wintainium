BeforeAll {
    $testRoot = Split-Path -Parent $PSScriptRoot
    $modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $modulePath -Force
}

Describe 'Wintainium authoritative reconciliation state boundary' {
    It 'converts Installed evidence and persists the observed version without using a selected release' {
        InModuleScope Wintainium.Core {
            $stateRoot = Join-Path $TestDrive 'installed'
            $operationId = [guid]::NewGuid().ToString()
            $priorState = New-WintainiumInstalledApplicationState -ApplicationId 'example.app' -InstallationState Installed -Version '1.0.0' -VersionSource 'Prior' -Architecture x64 -Channel stable -InstallationLocation '/opt/example'
            $evidence = [pscustomobject]@{
                ApplicationId='example.app'; InstallationState='Installed'; Version='2.1.0'; VersionSource='Observed'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example'; EvidenceSource='Fixture'
            }
            $reconciliation = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Reconciled'; Evidence=$evidence; Errors=@(); Warnings=@(); LogEvents=@() }

            $result = Invoke-WintainiumAuthoritativeStateReconciliation -StateRoot $stateRoot -OperationId $operationId -ApplicationId 'example.app' -ReconciliationResult $reconciliation -PriorState $priorState

            $result.IsSuccessful | Should -BeTrue
            $result.Persisted | Should -BeTrue
            $result.State.Version | Should -Be '2.1.0'
            $result.State.VersionSource | Should -Be 'Observed'
            (Get-WintainiumInstalledApplicationState -StateRoot $stateRoot -ApplicationId 'example.app').Version | Should -Be '2.1.0'
        }
    }

    It 'persists NotInstalled evidence and does not retain a stale version' {
        InModuleScope Wintainium.Core {
            $stateRoot = Join-Path $TestDrive 'not-installed'
            $operationId = [guid]::NewGuid().ToString()
            $priorState = New-WintainiumInstalledApplicationState -ApplicationId 'example.app' -InstallationState Installed -Version '2.0.0' -VersionSource 'Prior' -Architecture x64 -Channel stable -InstallationLocation '/opt/example'
            $evidence = [pscustomobject]@{ ApplicationId='example.app'; InstallationState='NotInstalled'; EvidenceSource='Fixture'; Architecture='x64'; Channel='stable'; Version=$null; VersionSource=$null; InstallationLocation=$null }
            $reconciliation = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Reconciled'; Evidence=$evidence; Errors=@(); Warnings=@(); LogEvents=@() }

            $result = Invoke-WintainiumAuthoritativeStateReconciliation -StateRoot $stateRoot -OperationId $operationId -ApplicationId 'example.app' -ReconciliationResult $reconciliation -PriorState $priorState

            $result.IsSuccessful | Should -BeTrue
            $result.Persisted | Should -BeTrue
            $result.State.InstallationState | Should -Be 'NotInstalled'
            $result.State.Version | Should -BeNullOrEmpty
            (Get-WintainiumInstalledApplicationState -StateRoot $stateRoot -ApplicationId 'example.app').InstallationState | Should -Be 'NotInstalled'
        }
    }

    It 'preserves prior authoritative state when reconciliation returns Unknown' {
        InModuleScope Wintainium.Core {
            $stateRoot = Join-Path $TestDrive 'unknown-preserve'
            $operationId = [guid]::NewGuid().ToString()
            $priorState = New-WintainiumInstalledApplicationState -ApplicationId 'example.app' -InstallationState Installed -Version '2.0.0' -VersionSource 'Prior' -Architecture x64 -Channel stable -InstallationLocation '/opt/example'
            Set-WintainiumInstalledApplicationState -StateRoot $stateRoot -State $priorState | Out-Null
            $evidence = [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Unknown'; EvidenceSource='Fixture' }
            $reconciliation = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Unknown'; Evidence=$evidence; Errors=@(); Warnings=@(); LogEvents=@() }

            $result = Invoke-WintainiumAuthoritativeStateReconciliation -StateRoot $stateRoot -OperationId $operationId -ApplicationId 'example.app' -ReconciliationResult $reconciliation -PriorState $priorState

            $result.IsSuccessful | Should -BeTrue
            $result.Persisted | Should -BeFalse
            $result.ReasonCode | Should -Be 'UnknownEvidencePreserved'
            $result.State.Version | Should -Be '2.0.0'
            (Get-WintainiumInstalledApplicationState -StateRoot $stateRoot -ApplicationId 'example.app').Version | Should -Be '2.0.0'
        }
    }

    It 'does not persist Unknown when no prior authoritative state exists' {
        InModuleScope Wintainium.Core {
            $stateRoot = Join-Path $TestDrive 'unknown-empty'
            $operationId = [guid]::NewGuid().ToString()
            $priorState = New-WintainiumInstalledApplicationState -ApplicationId 'example.app' -InstallationState Unknown
            $evidence = [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Unknown'; EvidenceSource='Fixture' }
            $reconciliation = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='Unknown'; Evidence=$evidence; Errors=@(); Warnings=@(); LogEvents=@() }

            $result = Invoke-WintainiumAuthoritativeStateReconciliation -StateRoot $stateRoot -OperationId $operationId -ApplicationId 'example.app' -ReconciliationResult $reconciliation -PriorState $priorState

            $result.IsSuccessful | Should -BeTrue
            $result.Persisted | Should -BeFalse
            $result.State.InstallationState | Should -Be 'Unknown'
            Test-Path (Join-Path $stateRoot 'installed-state.json') | Should -BeFalse
        }
    }

    It 'rejects reconciliation evidence with a mismatched OperationId without persistence' {
        InModuleScope Wintainium.Core {
            $stateRoot = Join-Path $TestDrive 'operation-id'
            $operationId = [guid]::NewGuid().ToString()
            $reconciliation = [pscustomobject]@{
                OperationId=[guid]::NewGuid().ToString(); IsSuccessful=$true; Status='Reconciled';
                Evidence=[pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='2.0.0'; VersionSource='Observed'; Architecture='x64'; Channel='stable'; EvidenceSource='Fixture' };
                Errors=@(); Warnings=@(); LogEvents=@()
            }

            $result = Invoke-WintainiumAuthoritativeStateReconciliation -StateRoot $stateRoot -OperationId $operationId -ApplicationId 'example.app' -ReconciliationResult $reconciliation -PriorState (New-WintainiumInstalledApplicationState -ApplicationId 'example.app' -InstallationState Unknown)

            $result.IsSuccessful | Should -BeFalse
            $result.Persisted | Should -BeFalse
            $result.ReasonCode | Should -Be 'OperationIdMismatch'
            Test-Path (Join-Path $stateRoot 'installed-state.json') | Should -BeFalse
        }
    }
}
