BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:manifestRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Manifests'
    $script:pluginRoot = Join-Path -Path $script:testRoot -ChildPath 'plugins'
    $script:schemaPath = Join-Path -Path $script:testRoot -ChildPath 'schemas/application-manifest.schema.json'

    Import-Module $script:modulePath -Force
}

Describe 'Core production Windows installed-application reconciliation workflow' {
    It 'discovers the production reconciler and invokes it through the Core reconciliation contract' {
        $manifestPath = Join-Path -Path $script:manifestRoot -ChildPath 'windows-installed-application-reconciliation.json'

        $validation = Test-WintainiumApplicationDefinition -ManifestPath $manifestPath -PluginRoot $script:pluginRoot -SchemaPath $script:schemaPath -OperationId '00000000-0000-0000-0000-00000000013D'

        $validation.IsValid | Should -BeTrue
        $validation.ReconciliationPlugin | Should -Not -BeNullOrEmpty
        $validation.ReconciliationPlugin.PluginId | Should -Be 'Wintainium.reconciliation.windows-installed-application'
        $validation.ReconciliationPlugin.PluginType | Should -Be 'Reconciliation'
        @($validation.ReconciliationPlugin.ContractVersions) | Should -Contain '1'
        $validation.ReconciliationPlugin.Capabilities.applicationState | Should -BeTrue

        $request = [pscustomobject][ordered]@{
            OperationId = $validation.OperationId
            ApplicationId = $validation.Manifest.Id
            Manifest = $validation.Manifest
            PriorState = $null
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Plugin = $validation.ReconciliationPlugin; Request = $request } {
            Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $Plugin -Request $Request
        }

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Reconciled'
        $result.OperationId | Should -Be $request.OperationId
        $result.Evidence.ApplicationId | Should -Be $request.ApplicationId
        $result.Evidence.InstallationState | Should -Be 'NotInstalled'
        $result.Evidence.EvidenceSource | Should -Be 'WindowsUninstallRegistry'
        $result.Evidence.Version | Should -BeNullOrEmpty
    }
}
