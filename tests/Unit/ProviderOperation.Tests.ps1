BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:pluginRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Plugins'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium provider operation contract' {
    BeforeAll {
        $script:registry = InModuleScope Wintainium.Core -Parameters @{ Path = $script:pluginRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }
        $script:provider = $script:registry.Plugins |
            Where-Object { $_.PluginType -eq 'Provider' -and $_.PluginId -eq 'Wintainium.provider.github-releases' }
    }

    It 'invokes a resolved provider through its fixed operation entry point' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000001'
            ApplicationId = 'example.application'
            ProviderId = $script:provider.PluginId
            RequiredContractVersion = '1'
            Settings = @{ repository = 'example/project' }
            DiscoveryContext = @{}
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $script:provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Success'
        $result.OperationId | Should -Be $request.OperationId
        $result.Releases.Count | Should -Be 1
        $result.Releases[0].Version | Should -Be '1.2.3'
        $result.Releases[0].Artifacts.Count | Should -Be 1
    }

    It 'preserves the Core operation correlation identifier in provider results and log events' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000002'
            ApplicationId = 'example.application'
            ProviderId = $script:provider.PluginId
            RequiredContractVersion = '1'
            Settings = @{}
            DiscoveryContext = @{}
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $script:provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        @($result.LogEvents | Where-Object { $_.OperationId -ne $request.OperationId }).Count | Should -Be 0
    }

    It 'represents no releases as a successful provider result' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000003'
            ApplicationId = 'example.application'
            ProviderId = $script:provider.PluginId
            RequiredContractVersion = '1'
            Settings = @{ mode = 'empty' }
            DiscoveryContext = @{}
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $script:provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'NoReleasesFound'
        $result.Releases.Count | Should -Be 0
        $result.Errors.Count | Should -Be 0
    }

    It 'converts a provider exception into a structured ProviderInternalError' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000004'
            ApplicationId = 'example.application'
            ProviderId = $script:provider.PluginId
            RequiredContractVersion = '1'
            Settings = @{ mode = 'throw' }
            DiscoveryContext = @{}
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $script:provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'ProviderInternalError'
        @($result.Errors.Code) | Should -Contain 'ProviderInternalError'
    }

    It 'rejects a provider result whose operation identifier does not match the request' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000005'
            ApplicationId = 'example.application'
            ProviderId = $script:provider.PluginId
            RequiredContractVersion = '1'
            Settings = @{ mode = 'bad-operation-id' }
            DiscoveryContext = @{}
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $script:provider; Request = $Request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'ProviderResultInvalid'
        @($result.Errors.Code) | Should -Contain 'ProviderResultOperationIdMismatch'
    }

    It 'rejects a provider result containing malformed normalized release data' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000006'
            ApplicationId = 'example.application'
            ProviderId = $script:provider.PluginId
            RequiredContractVersion = '1'
            Settings = @{ mode = 'bad-release' }
            DiscoveryContext = @{}
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $script:provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'ProviderResultInvalid'
        @($result.Errors.Code) | Should -Contain 'ProviderResultReleaseInvalid'
    }
}
