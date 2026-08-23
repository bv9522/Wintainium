BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:manifestRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Manifests'
    $script:pluginRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Plugins'
    $script:schemaPath = Join-Path -Path $script:testRoot -ChildPath 'schemas/application-manifest.schema.json'

    Import-Module $script:modulePath -Force
}

Describe 'Core provider discovery workflow' {
    It 'validates the manifest, resolves the provider, and returns normalized releases through Core' {
        $result = Get-WintainiumApplicationRelease `
            -ManifestPath (Join-Path -Path $script:manifestRoot -ChildPath 'valid-portable-zip.json') `
            -PluginRoot $script:pluginRoot `
            -SchemaPath $script:schemaPath

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Success'
        $result.Manifest.Id | Should -Be 'org.neovim.neovim'
        $result.ProviderPlugin.PluginId | Should -Be 'Wintainium.provider.github-releases'
        @($result.Releases).Count | Should -Be 1
        $result.Releases[0].ReleaseId | Should -Be 'fixture-release-1'
        $result.Releases[0].Version | Should -Be '1.2.3'
        $result.Releases[0].Artifacts[0].Format | Should -Be 'zip'
        $result.LogEvents.Count | Should -BeGreaterThan 2
    }

    It 'does not invoke a provider when application definition validation fails' {
        $result = Get-WintainiumApplicationRelease `
            -ManifestPath (Join-Path -Path $script:manifestRoot -ChildPath 'missing-provider.json') `
            -PluginRoot $script:pluginRoot `
            -SchemaPath $script:schemaPath

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'ApplicationDefinitionInvalid'
        @($result.Errors.Code) | Should -Contain 'ProviderNotRegistered'
        @($result.Releases).Count | Should -Be 0
    }

    It 'preserves one Core operation correlation identifier across validation and provider events' {
        $result = Get-WintainiumApplicationRelease `
            -ManifestPath (Join-Path -Path $script:manifestRoot -ChildPath 'valid-portable-zip.json') `
            -PluginRoot $script:pluginRoot `
            -SchemaPath $script:schemaPath

        $result.OperationId | Should -Not -BeNullOrEmpty
        @($result.LogEvents | Where-Object { $_.OperationId -ne $result.OperationId }).Count | Should -Be 0
    }
}
