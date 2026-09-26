$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Set-WintainiumInstalledApplicationStateFromReconciliation' {
    It 'persists installed reconciliation evidence as Core-owned authoritative state' {
        $stateRoot = Join-Path $TestDrive 'state'
        $result = InModuleScope Wintainium.Core -Parameters @{ Root=$stateRoot } {
            param($Root)
            $reconciliation = [pscustomobject][ordered]@{
                OperationId = '00000000-0000-0000-0000-00000000013F'
                IsSuccessful = $true
                Status = 'Reconciled'
                Evidence = [pscustomobject][ordered]@{ ApplicationId='org.example.app'; InstallationState='Installed'; EvidenceSource='WindowsUninstallRegistry'; Version='24.1'; VersionSource='Registry'; InstallationLocation='C:\Program Files\Example' }
                Errors=@(); Warnings=@(); LogEvents=@()
            }
            Set-WintainiumInstalledApplicationStateFromReconciliation -StateRoot $Root -ReconciliationResult $reconciliation
        }
        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'StateUpdated'
        $result.State.InstallationState | Should -Be 'Installed'
        $result.State.Version | Should -Be '24.1'
        $read = Get-WintainiumApplicationInstalledState -StateRoot $stateRoot -ApplicationId 'org.example.app' -OperationId '00000000-0000-0000-0000-00000000013F'
        $read.IsSuccessful | Should -BeTrue
        $read.State.InstallationState | Should -Be 'Installed'
        $read.State.VersionSource | Should -Be 'Registry'
    }

    It 'persists Unknown evidence without inventing version or architecture' {
        $stateRoot = Join-Path $TestDrive 'unknown-state'
        $result = InModuleScope Wintainium.Core -Parameters @{ Root=$stateRoot } {
            param($Root)
            Set-WintainiumInstalledApplicationStateFromReconciliation -StateRoot $Root -ReconciliationResult ([pscustomobject][ordered]@{ OperationId='00000000-0000-0000-0000-000000000140'; IsSuccessful=$true; Status='Unknown'; Evidence=[pscustomobject][ordered]@{ ApplicationId='org.example.app'; InstallationState='Unknown'; EvidenceSource='WindowsUninstallRegistry' }; Errors=@(); Warnings=@(); LogEvents=@() })
        }
        $result.IsSuccessful | Should -BeTrue
        $result.State.InstallationState | Should -Be 'Unknown'
        $result.State.Version | Should -BeNullOrEmpty
        $result.State.Architecture | Should -Be 'unknown'
    }

    It 'does not write state for an unsuccessful reconciliation result' {
        $stateRoot = Join-Path $TestDrive 'failed-state'
        $result = InModuleScope Wintainium.Core -Parameters @{ Root=$stateRoot } {
            param($Root)
            Set-WintainiumInstalledApplicationStateFromReconciliation -StateRoot $Root -ReconciliationResult ([pscustomobject][ordered]@{ OperationId='00000000-0000-0000-0000-000000000141'; IsSuccessful=$false; Status='ReconciliationInternalError'; Evidence=$null; Errors=@([pscustomobject]@{Code='Failure'}); Warnings=@(); LogEvents=@() })
        }
        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ReconciliationNotApplied'
        Test-Path (Join-Path $stateRoot 'installed-state.json') | Should -BeFalse
    }

    It 'clears stale version when reconciliation establishes NotInstalled' {
        $stateRoot = Join-Path $TestDrive 'not-installed-state'
        InModuleScope Wintainium.Core -Parameters @{ Root=$stateRoot } {
            param($Root)
            $state = New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Installed -Version '1.0' -VersionSource Registry
            Set-WintainiumInstalledApplicationState -StateRoot $Root -State $state | Out-Null
            Set-WintainiumInstalledApplicationStateFromReconciliation -StateRoot $Root -ReconciliationResult ([pscustomobject][ordered]@{ OperationId='00000000-0000-0000-0000-000000000142'; IsSuccessful=$true; Status='Reconciled'; Evidence=[pscustomobject][ordered]@{ApplicationId='org.example.app';InstallationState='NotInstalled';EvidenceSource='WindowsUninstallRegistry'}; Errors=@();Warnings=@();LogEvents=@() }) | Out-Null
        }
        $read = Get-WintainiumApplicationInstalledState -StateRoot $stateRoot -ApplicationId 'org.example.app'
        $read.State.InstallationState | Should -Be 'NotInstalled'
        $read.State.Version | Should -BeNullOrEmpty
    }
}