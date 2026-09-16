BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:pluginRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Plugins'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium reconciliation plugin contract' {
    BeforeAll {
        $script:registry = InModuleScope Wintainium.Core -Parameters @{ Path = $script:pluginRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }
        $script:reconciliation = $script:registry.Plugins |
            Where-Object { $_.PluginType -eq 'Reconciliation' -and $_.PluginId -eq 'Wintainium.reconciliation.valid-fixture' }
    }

    It 'registers and resolves a reconciliation plugin by contract and capability' {
        $script:reconciliation | Should -Not -BeNullOrEmpty

        $resolved = InModuleScope Wintainium.Core -Parameters @{
            Plugins = $script:registry.Plugins
            PluginId = $script:reconciliation.PluginId
        } {
            Resolve-WintainiumPlugin -Plugins $Plugins -PluginId $PluginId -PluginType Reconciliation -RequiredContractVersion '1' -RequiredCapabilities @('applicationState')
        }

        $resolved.IsResolved | Should -Be $true
        $resolved.Plugin.PluginType | Should -Be 'Reconciliation'
    }

    It 'returns authoritative-looking installed evidence without converting it into managed state' {
        $request = [pscustomobject][ordered]@{
            OperationId = '00000000-0000-0000-0000-000000000101'
            ApplicationId = 'example.application'
            Manifest = [pscustomobject]@{ id = 'example.application' }
            PriorState = $null
            Settings = @{}
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Plugin = $script:reconciliation; Request = $request } {
            Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $Plugin -Request $Request
        }

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Reconciled'
        $result.OperationId | Should -Be $request.OperationId
        $result.Evidence.InstallationState | Should -Be 'Installed'
        $result.Evidence.Version | Should -Be '1.2.3'
        $result.Evidence.EvidenceSource | Should -Be 'Fixture'
    }

    It 'preserves Unknown when the reconciliation source cannot establish installation state' {
        $request = [pscustomobject][ordered]@{
            OperationId = '00000000-0000-0000-0000-000000000102'
            ApplicationId = 'example.application'
            Manifest = [pscustomobject]@{ id = 'example.application' }
            PriorState = $null
            Settings = @{ mode = 'unknown' }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Plugin = $script:reconciliation; Request = $request } {
            Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $Plugin -Request $Request
        }

        $result.IsSuccessful | Should -Be $true
        $result.Evidence.InstallationState | Should -Be 'Unknown'
        $result.Evidence.Version | Should -BeNullOrEmpty
    }

    It 'supports an established NotInstalled observation without inventing a version' {
        $request = [pscustomobject][ordered]@{
            OperationId = '00000000-0000-0000-0000-000000000103'
            ApplicationId = 'example.application'
            Manifest = [pscustomobject]@{ id = 'example.application' }
            PriorState = $null
            Settings = @{ mode = 'not-installed' }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Plugin = $script:reconciliation; Request = $request } {
            Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $Plugin -Request $Request
        }

        $result.Evidence.InstallationState | Should -Be 'NotInstalled'
        $result.Evidence.Version | Should -BeNullOrEmpty
    }

    It 'rejects a reconciliation result with a mismatched OperationId' {
        $request = [pscustomobject][ordered]@{
            OperationId = '00000000-0000-0000-0000-000000000104'
            ApplicationId = 'example.application'
            Manifest = [pscustomobject]@{ id = 'example.application' }
            PriorState = $null
            Settings = @{ mode = 'bad-operation-id' }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Plugin = $script:reconciliation; Request = $request } {
            Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $Plugin -Request $Request
        }

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'ReconciliationResultInvalid'
        @($result.Errors.Code) | Should -Contain 'ReconciliationResultOperationIdMismatch'
    }

    It 'rejects evidence belonging to a different application' {
        $request = [pscustomobject][ordered]@{
            OperationId = '00000000-0000-0000-0000-000000000105'
            ApplicationId = 'example.application'
            Manifest = [pscustomobject]@{ id = 'example.application' }
            PriorState = $null
            Settings = @{ mode = 'bad-application-id' }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Plugin = $script:reconciliation; Request = $request } {
            Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $Plugin -Request $Request
        }

        $result.IsSuccessful | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'ReconciliationEvidenceApplicationIdMismatch'
    }

    It 'rejects an invalid normalized installation state' {
        $request = [pscustomobject][ordered]@{
            OperationId = '00000000-0000-0000-0000-000000000106'
            ApplicationId = 'example.application'
            Manifest = [pscustomobject]@{ id = 'example.application' }
            PriorState = $null
            Settings = @{ mode = 'bad-state' }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Plugin = $script:reconciliation; Request = $request } {
            Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $Plugin -Request $Request
        }

        $result.IsSuccessful | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'ReconciliationEvidenceInstallationStateInvalid'
    }

    It 'converts a reconciliation exception into a structured failure' {
        $request = [pscustomobject][ordered]@{
            OperationId = '00000000-0000-0000-0000-000000000107'
            ApplicationId = 'example.application'
            Manifest = [pscustomobject]@{ id = 'example.application' }
            PriorState = $null
            Settings = @{ mode = 'throw' }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Plugin = $script:reconciliation; Request = $request } {
            Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $Plugin -Request $Request
        }

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'ReconciliationInternalError'
        @($result.Errors.Code) | Should -Contain 'ReconciliationInternalError'
    }

    It 'does not provide the reconciliation plugin with state persistence authority' {
        $request = [pscustomobject][ordered]@{
            OperationId = '00000000-0000-0000-0000-000000000108'
            ApplicationId = 'example.application'
            Manifest = [pscustomobject]@{ id = 'example.application' }
            PriorState = $null
            Settings = @{}
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Plugin = $script:reconciliation; Request = $request } {
            Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $Plugin -Request $Request
        }

        $result.PSObject.Properties.Name | Should -Not -Contain 'StateRoot'
        $result.PSObject.Properties.Name | Should -Not -Contain 'PersistedState'
    }
}
