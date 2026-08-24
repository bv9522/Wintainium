BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:pluginRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Plugins'
    $script:providerContractFixtureRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/ProviderContracts'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium provider contract' {
    It 'requires provider discovery capabilities and a constrained module entry point' {
        $descriptorPath = Join-Path -Path $script:pluginRoot -ChildPath 'ValidProvider/plugin.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $true
        $result.Descriptor.entryPoint | Should -Be 'Wintainium.provider.valid-fixture.psm1'
        $result.Descriptor.capabilities.releaseDiscovery | Should -Be $true
        $result.Descriptor.capabilities.artifactDiscovery | Should -Be $true
    }

    It 'rejects a provider descriptor with an unsafe entry point' {
        $descriptorPath = Join-Path -Path $script:providerContractFixtureRoot -ChildPath 'UnsafeEntryPoint/plugin.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'DescriptorProviderEntryPointInvalid'
    }

    It 'rejects a provider descriptor without release discovery capability' {
        $descriptorPath = Join-Path -Path $script:providerContractFixtureRoot -ChildPath 'MissingReleaseDiscovery/plugin.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'DescriptorProviderReleaseDiscoveryMissing'
    }

    It 'rejects a provider descriptor without artifact discovery capability' {
        $descriptorPath = Join-Path -Path $script:providerContractFixtureRoot -ChildPath 'MissingArtifactDiscovery/plugin.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'DescriptorProviderArtifactDiscoveryMissing'
    }

    It 'distinguishes an unregistered provider from a contract-incompatible provider' {
        $registry = InModuleScope Wintainium.Core -Parameters @{ Path = $script:pluginRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }

        $missing = InModuleScope Wintainium.Core -Parameters @{ Plugins = $registry.Plugins } {
            Resolve-WintainiumPlugin -Plugins $Plugins -PluginId 'Wintainium.provider.missing' -PluginType Provider -RequiredContractVersion '1'
        }
        $incompatible = InModuleScope Wintainium.Core -Parameters @{ Plugins = $registry.Plugins } {
            Resolve-WintainiumPlugin -Plugins $Plugins -PluginId 'Wintainium.provider.github-releases' -PluginType Provider -RequiredContractVersion '2'
        }

        $missing.IsResolved | Should -Be $false
        $missing.Error.Code | Should -Be 'ProviderNotRegistered'
        $incompatible.IsResolved | Should -Be $false
        $incompatible.Error.Code | Should -Be 'ProviderContractIncompatible'
    }

    It 'rejects a resolved provider when a required capability is not declared' {
        $registry = InModuleScope Wintainium.Core -Parameters @{ Path = $script:pluginRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }
        $resolved = InModuleScope Wintainium.Core -Parameters @{ Plugins = $registry.Plugins } {
            Resolve-WintainiumPlugin -Plugins $Plugins -PluginId 'Wintainium.provider.github-releases' -PluginType Provider -RequiredContractVersion '1' -RequiredCapabilities @('unsupportedCapability')
        }

        $resolved.IsResolved | Should -Be $false
        $resolved.Error.Code | Should -Be 'ProviderCapabilityUnsupported'
    }

    It 'resolves a provider by stable id, compatible contract version, and capabilities' {
        $registry = InModuleScope Wintainium.Core -Parameters @{ Path = $script:pluginRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }
        $resolved = InModuleScope Wintainium.Core -Parameters @{ Plugins = $registry.Plugins } {
            Resolve-WintainiumPlugin -Plugins $Plugins -PluginId 'Wintainium.provider.github-releases' -PluginType Provider -RequiredContractVersion '1' -RequiredCapabilities @('releaseDiscovery', 'artifactDiscovery')
        }

        $resolved.IsResolved | Should -Be $true
        $resolved.Plugin.PluginType | Should -Be 'Provider'
        $resolved.Plugin.PluginId | Should -Be 'Wintainium.provider.github-releases'
        $resolved.Plugin.EntryPoint | Should -Be 'Wintainium.provider.valid-fixture.psm1'
    }
}
