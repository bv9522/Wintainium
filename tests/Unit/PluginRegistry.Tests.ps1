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

        $registry.Plugins.Count | Should -Be 7
        $registry.DescriptorErrors.Count | Should -Be 1
    }

    It 'registers the production EXE installer descriptor' {
        $productionPluginRoot = Join-Path $script:testRoot 'plugins'
        $registry = InModuleScope Wintainium.Core -Parameters @{ Path = $productionPluginRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }

        $registry.DescriptorErrors.Count | Should -Be 0
        @($registry.Plugins | Where-Object { $_.PluginId -eq 'Wintainium.provider.official-download-page' -and $_.PluginType -eq 'Provider' }).Count | Should -Be 1

        $installer = @($registry.Plugins | Where-Object {
            $_.PluginId -eq 'Wintainium.installer.exe' -and $_.PluginType -eq 'Installer'
        })

        $installer.Count | Should -Be 1
        @($installer[0].ContractVersions) | Should -Contain '1'
        @($installer[0].Capabilities.supportedFormats) | Should -Be @('exe')
        $installer[0].Capabilities.installationMode | Should -Be 'process'
        Test-Path -LiteralPath (Join-Path (Split-Path $installer[0].DescriptorPath -Parent) $installer[0].EntryPoint) -PathType Leaf | Should -Be $true
    }

    It 'default policy resolves the production EXE installer without ambiguity' {
        $productionPluginRoot = Join-Path $script:testRoot 'plugins'
        $registry = InModuleScope Wintainium.Core -Parameters @{ Path = $productionPluginRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }
        $policy = InModuleScope Wintainium.Core -Parameters @{ Registry = $registry } {
            Get-WintainiumDefaultApplicationPolicy -PluginRegistry $Registry
        }

        $policy.IsSuccessful | Should -Be $true
        $policy.Status | Should -Be 'Resolved'
        $policy.Policy.Installer.PluginId | Should -Be 'Wintainium.installer.exe'
        $policy.Policy.Installer.RequiredContractVersion | Should -Be '1'
        @($policy.Policy.Artifact.Formats) | Should -Be @('exe')
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

    It 'rejects duplicate plugin identities instead of selecting one deterministically' {
        $duplicatePlugins = @(
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.test'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('exe') }
                DescriptorPath = 'C:\plugins\one\plugin.json'
            },
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.test'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('exe') }
                DescriptorPath = 'C:\plugins\two\plugin.json'
            }
        )

        $resolved = InModuleScope Wintainium.Core -Parameters @{ Plugins = $duplicatePlugins } {
            Resolve-WintainiumPlugin -Plugins $Plugins -PluginId 'Wintainium.installer.test' -PluginType Installer -RequiredContractVersion '1'
        }

        $resolved.IsResolved | Should -Be $false
        $resolved.Plugin | Should -Be $null
        $resolved.Error.Code | Should -Be 'PluginIdentityAmbiguous'
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