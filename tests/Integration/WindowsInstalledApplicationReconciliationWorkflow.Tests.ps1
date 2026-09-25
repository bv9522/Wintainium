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

        $importResult = InModuleScope Wintainium.Core -Parameters @{ Path = $manifestPath; SchemaPath = $script:schemaPath } {
            Import-WintainiumManifest -Path $Path -SchemaPath $SchemaPath
        }
        $importResult.IsValid | Should -BeTrue
        $manifest = $importResult.Manifest

        $registry = Get-WintainiumPluginRegistry -PluginRoot $script:pluginRoot
        $resolution = Resolve-WintainiumPlugin -Plugins $registry.Plugins -PluginId $manifest.reconciliation.pluginId -PluginType Reconciliation -RequiredContractVersion $manifest.reconciliation.requiredContractVersion

        $resolution.IsResolved | Should -BeTrue
        $resolution.Plugin | Should -Not -BeNullOrEmpty
        $resolution.Plugin.PluginId | Should -Be 'Wintainium.reconciliation.windows-installed-application'
        $resolution.Plugin.PluginType | Should -Be 'Reconciliation'
        @($resolution.Plugin.ContractVersions) | Should -Contain '1'
        $resolution.Plugin.Capabilities.applicationState | Should -BeTrue

        $request = [pscustomobject][ordered]@{
            OperationId = '00000000-0000-0000-0000-00000000013D'
            ApplicationId = $manifest.Id
            Manifest = $manifest
            PriorState = $null
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Plugin = $resolution.Plugin; Request = $request } {
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
