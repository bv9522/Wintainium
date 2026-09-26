BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:manifestRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Manifests'
    $script:pluginRoot = Join-Path -Path $script:testRoot -ChildPath 'plugins'
    $script:schemaPath = Join-Path -Path $script:testRoot -ChildPath 'schemas/application-manifest.schema.json'

    Import-Module $script:modulePath -Force
}

Describe 'Real-application Windows installed-application reconciliation' {
    It 'reconciles the installed 7-Zip registration through the generic production path' {
        $manifestPath = Join-Path -Path $script:manifestRoot -ChildPath 'windows-7zip-reconciliation.json'

        $importResult = InModuleScope Wintainium.Core -Parameters @{
            Path = $manifestPath
            SchemaPath = $script:schemaPath
        } {
            Import-WintainiumManifest -Path $Path -SchemaPath $SchemaPath
        }

        $importResult.IsValid | Should -BeTrue
        $manifest = $importResult.Manifest

        $resolution = InModuleScope Wintainium.Core -Parameters @{
            PluginRoot = $script:pluginRoot
            PluginId = $manifest.reconciliation.pluginId
            RequiredContractVersion = $manifest.reconciliation.requiredContractVersion
        } {
            $registry = Get-WintainiumPluginRegistry -PluginRoot $PluginRoot
            Resolve-WintainiumPlugin -Plugins $registry.Plugins -PluginId $PluginId -PluginType Reconciliation -RequiredContractVersion $RequiredContractVersion
        }

        $resolution.IsResolved | Should -BeTrue
        $resolution.Plugin | Should -Not -BeNullOrEmpty
        $resolution.Plugin.PluginId | Should -Be 'Wintainium.reconciliation.windows-installed-application'
        $resolution.Plugin.PluginType | Should -Be 'Reconciliation'
        $resolution.Plugin.Capabilities.applicationState | Should -BeTrue

        $request = [pscustomobject][ordered]@{
            OperationId = '00000000-0000-0000-0000-00000000013E'
            ApplicationId = $manifest.Id
            Manifest = $manifest
            PriorState = $null
        }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Plugin = $resolution.Plugin
            Request = $request
        } {
            Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $Plugin -Request $Request
        }

        $result.IsSuccessful | Should -BeTrue -Because ("Status=$($result.Status); Errors=$(@($result.Errors | ForEach-Object { $_.Code + ': ' + $_.Message }) -join ' | '); Warnings=$(@($result.Warnings | ForEach-Object { $_.Code + ': ' + $_.Message }) -join ' | ')")
        $result.Status | Should -Be 'Reconciled'
        $result.OperationId | Should -Be $request.OperationId
        $result.Evidence.ApplicationId | Should -Be $request.ApplicationId
        $result.Evidence.InstallationState | Should -Be 'Installed'
        $result.Evidence.EvidenceSource | Should -Be 'WindowsUninstallRegistry'
        $result.Evidence.Version | Should -Not -BeNullOrEmpty
        $result.Evidence.VersionSource | Should -Be 'Registry'

        $stateRoot = Join-Path $TestDrive 'installed-state'
        $stateUpdate = InModuleScope Wintainium.Core -Parameters @{
            Root = $stateRoot
            ReconciliationResult = $result
        } {
            param($Root, $ReconciliationResult)
            Set-WintainiumInstalledApplicationStateFromReconciliation -StateRoot $Root -ReconciliationResult $ReconciliationResult
        }

        $stateUpdate.IsSuccessful | Should -BeTrue
        $stateUpdate.Status | Should -Be 'StateUpdated'
        $stateUpdate.State.InstallationState | Should -Be 'Installed'
        $stateUpdate.State.Version | Should -Be $result.Evidence.Version

        $authoritative = Get-WintainiumApplicationInstalledState -StateRoot $stateRoot -ApplicationId $request.ApplicationId -OperationId $request.OperationId
        $authoritative.IsSuccessful | Should -BeTrue
        $authoritative.Status | Should -Be 'Installed'
        $authoritative.State.ApplicationId | Should -Be $request.ApplicationId
        $authoritative.State.InstallationState | Should -Be 'Installed'
        $authoritative.State.Version | Should -Be $result.Evidence.Version
        $authoritative.State.VersionSource | Should -Be 'Registry'
        $authoritative.State.Architecture | Should -Be 'unknown'
    }
}
