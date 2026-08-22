$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
$schemaPath = Join-Path -Path $testRoot -ChildPath 'schemas/application-manifest.schema.json'
$fixtureRoot = Join-Path -Path $testRoot -ChildPath 'tests/Fixtures/Manifests'
$pluginRoot = Join-Path -Path $testRoot -ChildPath 'tests/Fixtures/Plugins'

Import-Module $modulePath -Force

Describe 'Test-WintainiumApplicationDefinition public contract' {
    It 'returns the complete stable result shape for a valid application definition' {
        $result = Test-WintainiumApplicationDefinition `
            -ManifestPath (Join-Path -Path $fixtureRoot -ChildPath 'valid-portable-zip.json') `
            -PluginRoot $pluginRoot `
            -SchemaPath $schemaPath

        $result.PSObject.Properties.Name | Should -Contain 'OperationId'
        $result.PSObject.Properties.Name | Should -Contain 'IsValid'
        $result.PSObject.Properties.Name | Should -Contain 'Manifest'
        $result.PSObject.Properties.Name | Should -Contain 'ProviderPlugin'
        $result.PSObject.Properties.Name | Should -Contain 'InstallerPlugin'
        $result.PSObject.Properties.Name | Should -Contain 'Errors'
        $result.PSObject.Properties.Name | Should -Contain 'Warnings'
        $result.PSObject.Properties.Name | Should -Contain 'LogEvents'

        $result.OperationId | Should -Not -BeNullOrEmpty
        $result.IsValid | Should -Be $true
        $result.Manifest | Should -Not -BeNullOrEmpty
        $result.ProviderPlugin | Should -Not -BeNullOrEmpty
        $result.InstallerPlugin | Should -Not -BeNullOrEmpty
        $result.Errors.Count | Should -Be 0
    }

    It 'returns a stable invalid result when the manifest cannot be loaded' {
        $missingManifest = Join-Path -Path $TestDrive -ChildPath 'does-not-exist.json'

        $result = Test-WintainiumApplicationDefinition `
            -ManifestPath $missingManifest `
            -PluginRoot $pluginRoot `
            -SchemaPath $schemaPath

        $result.PSObject.Properties.Name | Should -Contain 'OperationId'
        $result.PSObject.Properties.Name | Should -Contain 'IsValid'
        $result.PSObject.Properties.Name | Should -Contain 'Manifest'
        $result.PSObject.Properties.Name | Should -Contain 'ProviderPlugin'
        $result.PSObject.Properties.Name | Should -Contain 'InstallerPlugin'
        $result.PSObject.Properties.Name | Should -Contain 'Errors'
        $result.PSObject.Properties.Name | Should -Contain 'Warnings'
        $result.PSObject.Properties.Name | Should -Contain 'LogEvents'

        $result.OperationId | Should -Not -BeNullOrEmpty
        $result.IsValid | Should -Be $false
        $result.Manifest | Should -BeNullOrEmpty
        $result.ProviderPlugin | Should -BeNullOrEmpty
        $result.InstallerPlugin | Should -BeNullOrEmpty
        $result.Errors.Count | Should -BeGreaterThan 0
        $result.LogEvents.Count | Should -BeGreaterThan 0
    }

    It 'returns structured plugin resolution failures without throwing' {
        $manifest = Join-Path -Path $TestDrive -ChildPath 'missing-plugin.json'
        @'
{
  "manifestVersion": "1.0",
  "id": "org.example.missing-plugin",
  "name": "Missing Plugin Example",
  "source": {
    "pluginId": "provider.does-not-exist",
    "requiredContractVersion": "1.0"
  },
  "installer": {
    "pluginId": "installer.does-not-exist",
    "requiredContractVersion": "1.0"
  }
}
'@ | Set-Content -LiteralPath $manifest -Encoding utf8

        $result = Test-WintainiumApplicationDefinition `
            -ManifestPath $manifest `
            -PluginRoot $pluginRoot `
            -SchemaPath $schemaPath

        $result.IsValid | Should -Be $false
        $result.Errors.Count | Should -BeGreaterThan 0
        $result.Errors[0].Code | Should -Not -BeNullOrEmpty
        $result.OperationId | Should -Not -BeNullOrEmpty
    }
}
