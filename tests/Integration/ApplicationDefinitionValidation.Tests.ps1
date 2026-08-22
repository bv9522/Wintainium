BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:manifestRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Manifests'
    $script:pluginRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Plugins'
    $script:schemaPath = Join-Path -Path $script:testRoot -ChildPath 'schemas/application-manifest.schema.json'

    Import-Module $script:modulePath -Force
}

Describe 'Application definition validation workflow' {
    It 'validates and resolves a portable ZIP application definition offline' {
        $result = Test-WintainiumApplicationDefinition `
            -ManifestPath (Join-Path -Path $script:manifestRoot -ChildPath 'valid-portable-zip.json') `
            -PluginRoot $script:pluginRoot `
            -SchemaPath $script:schemaPath

        $result.IsValid | Should -Be $true
        $result.ProviderPlugin.PluginId | Should -Be 'Wintainium.provider.github-releases'
        $result.InstallerPlugin.PluginId | Should -Be 'Wintainium.installer.portable-zip'
        $result.LogEvents.Count | Should -Be 2
    }

    It 'reports a missing provider without contacting an external service' {
        $result = Test-WintainiumApplicationDefinition `
            -ManifestPath (Join-Path -Path $script:manifestRoot -ChildPath 'missing-provider.json') `
            -PluginRoot $script:pluginRoot `
            -SchemaPath $script:schemaPath

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'ProviderNotRegistered'
    }

    It 'reports an incompatible installer capability' {
        $result = Test-WintainiumApplicationDefinition `
            -ManifestPath (Join-Path -Path $script:manifestRoot -ChildPath 'incompatible-installer.json') `
            -PluginRoot $script:pluginRoot `
            -SchemaPath $script:schemaPath

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'InstallerArtifactIncompatible'
    }
}
