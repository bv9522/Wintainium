BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:providerPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.provider.github-releases/Wintainium.provider.github-releases.psm1'
    $script:descriptorPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.provider.github-releases/plugin.json'
    Import-Module $script:modulePath -Force
}

Describe 'Wintainium source resolution contract' {
    BeforeEach {
        $script:provider = [pscustomobject][ordered]@{
            PluginId = 'Wintainium.provider.github-releases'
            PluginType = 'Provider'
            ContractVersions = @('1')
            EntryPoint = 'Wintainium.provider.github-releases.psm1'
            Capabilities = @{ releaseDiscovery = $true; artifactDiscovery = $true; sourceResolution = $true }
            DescriptorPath = $script:descriptorPath
        }
    }

    It 'resolves a GitHub repository URL without contacting GitHub' {
        $result = InModuleScope Wintainium.Core -Parameters @{ Provider=$script:provider } {
            Invoke-WintainiumProviderSourceResolution -Provider $Provider -Request ([pscustomobject]@{
                OperationId='source-test-1'; SourceUri='https://github.com/PCSX2/pcsx2'
            })
        }

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Resolved'
        $result.OperationId | Should -Be 'source-test-1'
        $result.Source.ApplicationId | Should -Be 'github.pcsx2.pcsx2'
        $result.Source.ProviderId | Should -Be 'Wintainium.provider.github-releases'
        $result.Source.ProviderSettings.repository | Should -Be 'PCSX2/pcsx2'
        $result.Source.CanonicalUri | Should -Be 'https://github.com/PCSX2/pcsx2'
    }

    It 'resolves a GitHub release tag URL and preserves release context' {
        $result = InModuleScope Wintainium.Core -Parameters @{ Provider=$script:provider } {
            Invoke-WintainiumProviderSourceResolution -Provider $Provider -Request ([pscustomobject]@{
                OperationId='source-test-2'; SourceUri='https://github.com/PCSX2/pcsx2/releases/tag/v2.9.78'
            })
        }

        $result.IsSuccessful | Should -Be $true
        $result.Source.SourceContext.repository | Should -Be 'PCSX2/pcsx2'
        $result.Source.SourceContext.releaseTag | Should -Be 'v2.9.78'
    }

    It 'accepts a GitHub releases collection URL as repository identity' {
        $result = InModuleScope Wintainium.Core -Parameters @{ Provider=$script:provider } {
            Invoke-WintainiumProviderSourceResolution -Provider $Provider -Request ([pscustomobject]@{
                OperationId='source-test-3'; SourceUri='https://github.com/PCSX2/pcsx2/releases'
            })
        }

        $result.IsSuccessful | Should -Be $true
        $result.Source.ProviderSettings.repository | Should -Be 'PCSX2/pcsx2'
        $result.Source.SourceContext.PSObject.Properties.Name | Should -Not -Contain 'releaseTag'
    }

    It 'rejects non-HTTP source URIs before provider execution' {
        $result = InModuleScope Wintainium.Core -Parameters @{ Provider=$script:provider } {
            Invoke-WintainiumProviderSourceResolution -Provider $Provider -Request ([pscustomobject]@{
                OperationId='source-test-4'; SourceUri='file:///C:/software.exe'
            })
        }

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceInvalid'
        @($result.Errors.Code) | Should -Contain 'SourceResolutionUriInvalid'
    }

    It 'rejects a provider that does not advertise source resolution' {
        $script:provider.Capabilities.sourceResolution = $false
        $result = InModuleScope Wintainium.Core -Parameters @{ Provider=$script:provider } {
            Invoke-WintainiumProviderSourceResolution -Provider $Provider -Request ([pscustomobject]@{
                OperationId='source-test-5'; SourceUri='https://github.com/PCSX2/pcsx2'
            })
        }

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceUnsupported'
        @($result.Errors.Code) | Should -Contain 'SourceResolutionCapabilityUnsupported'
    }

    It 'rejects a source resolver result that omits normalized source facts' {
        $fixturePath = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/ProviderContracts/ValidProvider/Wintainium.provider.valid-fixture.psm1'
        $result = InModuleScope Wintainium.Core -Parameters @{ Provider=$script:provider } {
            $Provider.EntryPoint = 'Wintainium.provider.valid-fixture.psm1'
            $Provider.DescriptorPath = $fixturePath
            Invoke-WintainiumProviderSourceResolution -Provider $Provider -Request ([pscustomobject]@{
                OperationId='source-test-6'; SourceUri='https://github.com/PCSX2/pcsx2'
            })
        }

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceResolverInternalError'
    }
}
