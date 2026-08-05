$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
$manifestRoot = Join-Path -Path $testRoot -ChildPath 'tests/Fixtures/Manifests'
$pluginRoot = Join-Path -Path $testRoot -ChildPath 'tests/Fixtures/Plugins'

Import-Module $modulePath -Force

Describe 'Application definition validation workflow' {
    It 'validates and resolves a portable ZIP application definition offline' {
        $result = Test-WintainiumApplicationDefinition -ManifestPath (Join-Path -Path $manifestRoot -ChildPath 'valid-portable-zip.json') -PluginRoot $pluginRoot

        $result.IsValid | Should Be $true
        $result.ProviderPlugin.PluginId | Should Be 'Wintainium.provider.github-releases'
        $result.InstallerPlugin.PluginId | Should Be 'Wintainium.installer.portable-zip'
        $result.LogEvents.Count | Should Be 2
    }

    It 'reports a missing provider without contacting an external service' {
        $result = Test-WintainiumApplicationDefinition -ManifestPath (Join-Path -Path $manifestRoot -ChildPath 'missing-provider.json') -PluginRoot $pluginRoot

        $result.IsValid | Should Be $false
        ($result.Errors.Code -eq 'PluginNotResolved') | Should Be $true
    }

    It 'reports an incompatible installer capability' {
        $result = Test-WintainiumApplicationDefinition -ManifestPath (Join-Path -Path $manifestRoot -ChildPath 'incompatible-installer.json') -PluginRoot $pluginRoot

        $result.IsValid | Should Be $false
        ($result.Errors.Code -eq 'InstallerArtifactIncompatible') | Should Be $true
    }
}
