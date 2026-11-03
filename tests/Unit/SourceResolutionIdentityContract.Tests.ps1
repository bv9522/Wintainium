BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force
}

Describe 'Wintainium source-resolution identity contract hardening' {
    It 'rejects a non-Boolean resolver success indicator instead of coercing it' {
        $providerRoot = Join-Path $TestDrive 'non-boolean-provider'
        New-Item -ItemType Directory -Path $providerRoot -Force | Out-Null
        $modulePath = Join-Path $providerRoot 'identity-fixture.psm1'
        @'
function Invoke-WintainiumProviderSourceResolution {
    param([Parameter(Mandatory)][object]$Request)
    $source = [pscustomobject][ordered]@{
        ApplicationId = 'web.example.com.product'
        Name = 'Example Product'
        CanonicalUri = 'https://example.com/product'
        ProviderId = 'Wintainium.provider.identity-fixture'
        ProviderContractVersion = '1'
        ProviderSettings = @{}
    }
    [pscustomobject][ordered]@{
        OperationId = $Request.OperationId
        IsSuccessful = 'false'
        Status = 'Resolved'
        Source = $source
        Errors = @()
        Warnings = @()
        LogEvents = @()
    }
}
Export-ModuleMember -Function Invoke-WintainiumProviderSourceResolution
'@ | Set-Content -LiteralPath $modulePath -Encoding utf8

        $provider = [pscustomobject][ordered]@{
            PluginId = 'Wintainium.provider.identity-fixture'
            PluginType = 'Provider'
            ContractVersions = @('1')
            EntryPoint = 'identity-fixture.psm1'
            Capabilities = @{ sourceResolution = $true }
            DescriptorPath = (Join-Path $providerRoot 'plugin.json')
        }
        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $provider } {
            Invoke-WintainiumCoreProviderSourceResolution -Provider $Provider -Request ([pscustomobject]@{
                OperationId = 'identity-type-test'
                SourceUri = 'https://example.com/product'
            })
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'SourceResolutionResultInvalid'
        @($result.Errors.Code) | Should -Contain 'SourceResolutionResultInvalid'
        $result.Errors[0].Message | Should -Match 'IsSuccessful must be a Boolean'
    }

    It 'preserves and normalizes provider-supplied identity aliases through manifest persistence' {
        $source = [pscustomobject][ordered]@{
            ApplicationId = 'web.example.com.product'
            Name = 'Example Product'
            CanonicalUri = 'https://example.com/product'
            ProviderId = 'Wintainium.provider.identity-fixture'
            ProviderContractVersion = '1'
            ProviderSettings = [ordered]@{ product = 'product' }
            SourceContext = [ordered]@{ repository = 'example/product'; releaseTag = 'v2.4.0' }
            Aliases = @('Example Product Legacy', 'EXAMPLE PRODUCT LEGACY', 'Example Product', 'Alternate Product')
        }
        $policy = [pscustomobject][ordered]@{
            Installer = [pscustomobject]@{ PluginId = 'Wintainium.installer.fixture'; RequiredContractVersion = '1'; Settings = @{} }
            Reconciliation = [pscustomobject]@{ PluginId = 'Wintainium.reconciliation.fixture'; RequiredContractVersion = '1'; Settings = @{} }
            Release = [pscustomobject]@{ Channel = 'stable' }
            Artifact = [pscustomobject]@{ Formats = @('exe'); Architectures = @('x64'); AllowUnknownArchitecture = $false }
        }

        $normalized = InModuleScope Wintainium.Core -Parameters @{ Source = $source; Policy = $policy } {
            New-WintainiumApplicationDefinitionFromSource -Source $Source -Policy $Policy -OperationId 'identity-alias-test'
        }
        $normalized.IsSuccessful | Should -BeTrue
        @($normalized.ApplicationDefinition.aliases) | Should -Be @('Example Product Legacy', 'Alternate Product')
        $normalized.ApplicationDefinition.source.context.repository | Should -Be 'example/product'
        $normalized.ApplicationDefinition.source.context.releaseTag | Should -Be 'v2.4.0'
        $normalized.ApplicationDefinition | Add-Member -NotePropertyName userConfirmedAliases -NotePropertyValue @('Example Product (Legacy User Name)') -Force

        $manifestRoot = Join-Path $TestDrive 'identity-alias-manifests'
        $manifestPath = InModuleScope Wintainium.Core -Parameters @{ Definition = $normalized.ApplicationDefinition; Root = $manifestRoot } {
            Set-WintainiumApplicationDefinition -ApplicationDefinition $Definition -ManifestRoot $Root
        }
        $persisted = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
        @($persisted.aliases) | Should -Be @('Example Product Legacy', 'Alternate Product')
        $persisted.source.context.repository | Should -Be 'example/product'
        $persisted.source.context.releaseTag | Should -Be 'v2.4.0'
        @($persisted.userConfirmedAliases) | Should -Be @('Example Product (Legacy User Name)')
    }

    It 'rejects a non-dictionary provider source context during normalization' {
        $source = [pscustomobject][ordered]@{
            ApplicationId = 'web.example.com.product'
            Name = 'Example Product'
            CanonicalUri = 'https://example.com/product'
            ProviderId = 'Wintainium.provider.identity-fixture'
            ProviderContractVersion = '1'
            ProviderSettings = [ordered]@{ product = 'product' }
            SourceContext = 'releaseTag=v2.4.0'
        }
        $policy = [pscustomobject][ordered]@{
            Installer = [pscustomobject]@{ PluginId = 'Wintainium.installer.fixture'; RequiredContractVersion = '1'; Settings = @{} }
            Reconciliation = [pscustomobject]@{ PluginId = 'Wintainium.reconciliation.fixture'; RequiredContractVersion = '1'; Settings = @{} }
            Release = [pscustomobject]@{ Channel = 'stable' }
            Artifact = [pscustomobject]@{ Formats = @('exe'); Architectures = @('x64'); AllowUnknownArchitecture = $false }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Source = $source; Policy = $policy } {
            New-WintainiumApplicationDefinitionFromSource -Source $Source -Policy $Policy -OperationId 'invalid-context-test'
        }

        $result.IsSuccessful | Should -BeFalse
        @($result.Errors.Code) | Should -Contain 'ApplicationSourceContextInvalid'
    }
    It 'rejects source context that exceeds the supported nesting limit' {
        $context = @{ value = 'leaf' }
        for ($index = 0; $index -lt 10; $index++) {
            $context = @{ nested = $context }
        }
        $manifest = @{ source = @{ context = $context } }
        $result = InModuleScope Wintainium.Core -Parameters @{ Manifest = $manifest } {
            Test-WintainiumManifestSemantics -Manifest $Manifest
        }

        @($result.Code) | Should -Contain 'ManifestSourceContextInvalid'
    }

    It 'rejects credential-like keys in provider source context before persistence' {
        $source = [pscustomobject][ordered]@{
            ApplicationId = 'web.example.com.product'
            Name = 'Example Product'
            CanonicalUri = 'https://example.com/product'
            ProviderId = 'Wintainium.provider.identity-fixture'
            ProviderContractVersion = '1'
            ProviderSettings = [ordered]@{ product = 'product' }
            SourceContext = [ordered]@{ nested = [ordered]@{ accessToken = 'must-not-persist' } }
        }
        $policy = [pscustomobject][ordered]@{
            Installer = [pscustomobject]@{ PluginId = 'Wintainium.installer.fixture'; RequiredContractVersion = '1'; Settings = @{} }
            Reconciliation = [pscustomobject]@{ PluginId = 'Wintainium.reconciliation.fixture'; RequiredContractVersion = '1'; Settings = @{} }
            Release = [pscustomobject]@{ Channel = 'stable' }
            Artifact = [pscustomobject]@{ Formats = @('exe'); Architectures = @('x64'); AllowUnknownArchitecture = $false }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Source = $source; Policy = $policy } {
            New-WintainiumApplicationDefinitionFromSource -Source $Source -Policy $Policy -OperationId 'credential-context-test'
        }

        $result.IsSuccessful | Should -BeFalse
        @($result.Errors.Code) | Should -Contain 'ManifestContainsProhibitedInformation'
    }

}
