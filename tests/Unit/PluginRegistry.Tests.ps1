BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:pluginRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Plugins'
    $script:manifestRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Manifests'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium plugin registry' {
    It 'registers valid plugin descriptors and reports malformed descriptors' {
        $registry = InModuleScope Wintainium.Core -Parameters @{ Path = $script:pluginRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }

        $registry.Plugins.Count | Should -Be 5
        $registry.DescriptorErrors.Count | Should -Be 1
    }

    It 'resolves an installer by id, type, and contract version' {
        $registry = InModuleScope Wintainium.Core -Parameters @{ Path = $script:pluginRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }
        $resolved = InModuleScope Wintainium.Core -Parameters @{ Plugins = $registry.Plugins } {
            Resolve-WintainiumPlugin -Plugins $Plugins -PluginId 'Wintainium.installer.portable-zip' -PluginType Installer -RequiredContractVersion '1'
        }

        $resolved.IsResolved | Should -Be $true
        $resolved.Plugin.PluginType | Should -Be 'Installer'
    }

    It 'rejects an installer that supports none of the requested formats' {
        $manifestPath = Join-Path -Path $script:manifestRoot -ChildPath 'incompatible-installer.json'
        $registry = InModuleScope Wintainium.Core -Parameters @{ Path = $script:pluginRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $manifestPath; Plugins = $registry.Plugins } {
            $manifest = (Import-WintainiumManifest -Path $Path).Manifest
            $installer = Resolve-WintainiumPlugin -Plugins $Plugins -PluginId $manifest.installer.pluginId -PluginType Installer -RequiredContractVersion $manifest.installer.requiredContractVersion
            Test-WintainiumInstallerCompatibility -Manifest $manifest -InstallerPlugin $installer.Plugin
        }

        $result.IsCompatible | Should -Be $false
        $result.Error.Code | Should -Be 'InstallerArtifactIncompatible'
    }
}
