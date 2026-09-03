BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:pluginRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Plugins'
    $script:installerContractFixtureRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/InstallerDescriptors'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium installer descriptor contract' {
    It 'accepts a valid installer descriptor and exposes supported formats' {
        $descriptorPath = Join-Path -Path $script:pluginRoot -ChildPath 'ValidInstaller/plugin.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $true
        @($result.Descriptor.capabilities.supportedFormats) | Should -Be @('zip')
    }

    It 'accepts multiple distinct supported formats' {
        $descriptorPath = Join-Path -Path $script:installerContractFixtureRoot -ChildPath 'MultipleFormats/plugin.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $true
        @($result.Descriptor.capabilities.supportedFormats) | Should -Be @('exe', 'msi')
    }

    It 'rejects a non-string supported format' {
        $descriptorPath = Join-Path -Path $script:installerContractFixtureRoot -ChildPath 'NonStringFormat/plugin.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'DescriptorInstallerFormatsInvalid'
    }

    It 'rejects an empty supported format' {
        $descriptorPath = Join-Path -Path $script:installerContractFixtureRoot -ChildPath 'EmptyFormat/plugin.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'DescriptorInstallerFormatsInvalid'
    }

    It 'rejects a malformed supported format identifier' {
        $descriptorPath = Join-Path -Path $script:installerContractFixtureRoot -ChildPath 'MalformedFormat/plugin.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'DescriptorInstallerFormatsInvalid'
    }

    It 'rejects duplicate supported formats case-insensitively' {
        $descriptorPath = Join-Path -Path $script:installerContractFixtureRoot -ChildPath 'DuplicateFormats/plugin.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'DescriptorInstallerFormatsDuplicate'
    }

    It 'rejects an installer descriptor without supported formats' {
        $descriptorPath = Join-Path -Path $script:installerContractFixtureRoot -ChildPath 'MissingFormats/plugin.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'DescriptorInstallerFormatsMissing'
    }
}
