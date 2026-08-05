$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
$pluginRoot = Join-Path -Path $testRoot -ChildPath 'tests/Fixtures/Plugins'

Import-Module $modulePath -Force
$module = Get-Module Wintainium.Core

Describe 'Wintainium plugin registry' {
    It 'registers valid plugin descriptors and reports malformed descriptors' {
        $registry = & $module {
            param($path)
            Get-WintainiumPluginRegistry -PluginRoot $path
        } $pluginRoot

        $registry.Plugins.Count | Should Be 5
        $registry.DescriptorErrors.Count | Should Be 1
    }

    It 'resolves an installer by id, type, and contract version' {
        $registry = & $module {
            param($path)
            Get-WintainiumPluginRegistry -PluginRoot $path
        } $pluginRoot
        $resolved = & $module {
            param($plugins)
            Resolve-WintainiumPlugin -Plugins $plugins -PluginId 'Wintainium.installer.portable-zip' -PluginType Installer -RequiredContractVersion '1'
        } $registry.Plugins

        $resolved.IsResolved | Should Be $true
        $resolved.Plugin.PluginType | Should Be 'Installer'
    }

    It 'rejects an installer that supports none of the requested formats' {
        $manifestPath = Join-Path -Path $testRoot -ChildPath 'tests/Fixtures/Manifests/incompatible-installer.json'
        $registry = & $module {
            param($path)
            Get-WintainiumPluginRegistry -PluginRoot $path
        } $pluginRoot
        $result = & $module {
            param($path, $plugins)
            $manifest = (Import-WintainiumManifest -Path $path).Manifest
            $installer = Resolve-WintainiumPlugin -Plugins $plugins -PluginId $manifest.installer.pluginId -PluginType Installer -RequiredContractVersion $manifest.installer.requiredContractVersion
            Test-WintainiumInstallerCompatibility -Manifest $manifest -InstallerPlugin $installer.Plugin
        } $manifestPath $registry.Plugins

        $result.IsCompatible | Should Be $false
        $result.Error.Code | Should Be 'InstallerArtifactIncompatible'
    }
}
