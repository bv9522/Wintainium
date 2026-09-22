BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force
}

Describe 'Wintainium normalized application model' {
    BeforeAll {
        $script:source = [pscustomobject][ordered]@{
            ApplicationId='github.microsoft.powertoys'; Name='PowerToys'; Publisher='microsoft'
            Homepage='https://github.com/microsoft/PowerToys'; CanonicalUri='https://github.com/microsoft/PowerToys'
            ProviderId='Wintainium.provider.github-releases'; ProviderContractVersion='1'
            ProviderSettings=@{ repository='microsoft/PowerToys' }; SourceContext=@{ repository='microsoft/PowerToys' }
        }
        $script:policy = [pscustomobject][ordered]@{
            Installer=[pscustomobject]@{ PluginId='Wintainium.installer.valid-fixture'; RequiredContractVersion='1'; Settings=@{} }
            Reconciliation=[pscustomobject]@{ PluginId='Wintainium.reconciliation.valid-fixture'; RequiredContractVersion='1'; Settings=@{} }
            Release=[pscustomobject]@{ Channel='stable' }
            Artifact=[pscustomobject]@{ Formats=@('exe','msi','zip'); Architectures=@('x64','x86','arm64','neutral'); AllowUnknownArchitecture=$true }
        }
    }

    It 'constructs the existing application-definition shape from normalized source facts' {
        $result = & (Get-Module Wintainium.Core) {
            param($source, $policy)
            New-WintainiumApplicationDefinitionFromSource -Source $source -Policy $policy -OperationId 'model-test-1'
        } $script:source $script:policy

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Resolved'
        $result.OperationId | Should -Be 'model-test-1'
        $result.ApplicationDefinition.Id | Should -Be 'github.microsoft.powertoys'
        $result.ApplicationDefinition.Name | Should -Be 'PowerToys'
        $result.ApplicationDefinition.Source.pluginId | Should -Be 'Wintainium.provider.github-releases'
        $result.ApplicationDefinition.Source.settings.repository | Should -Be 'microsoft/PowerToys'
        $result.ApplicationDefinition.Installer.pluginId | Should -Be 'Wintainium.installer.valid-fixture'
        $result.ApplicationDefinition.Reconciliation.pluginId | Should -Be 'Wintainium.reconciliation.valid-fixture'
        @($result.ApplicationDefinition.Artifact.formats) | Should -Be @('exe','msi','zip')
    }

    It 'does not invent installer or lifecycle policy when Core-owned policy is absent' {
        $result = & (Get-Module Wintainium.Core) {
            param($source)
            New-WintainiumApplicationDefinitionFromSource -Source $source -Policy $null -OperationId 'model-test-2'
        } $script:source

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'ApplicationDefinitionInvalid'
        @($result.Errors.Code) | Should -Contain 'ApplicationPolicyMissing'
        $result.ApplicationDefinition | Should -Be $null
    }

    It 'rejects incomplete normalized source facts before constructing an application definition' {
        $incomplete = [pscustomobject]@{
            ApplicationId='github.example.project'; Name='Example'; ProviderId='Wintainium.provider.github-releases'
            ProviderContractVersion='1'; ProviderSettings=@{ repository='example/project' }
        }
        $result = & (Get-Module Wintainium.Core) {
            param($source, $policy)
            New-WintainiumApplicationDefinitionFromSource -Source $source -Policy $policy -OperationId 'model-test-3'
        } $incomplete $script:policy

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'ApplicationDefinitionInvalid'
        @($result.Errors.Code) | Should -Contain 'ApplicationSourceIncomplete'
    }

    It 'produces an application definition that satisfies the manifest schema' {
        $result = & (Get-Module Wintainium.Core) {
            param($source, $policy)
            New-WintainiumApplicationDefinitionFromSource -Source $source -Policy $policy -OperationId 'model-test-5'
        } $script:source $script:policy

        $json = $result.ApplicationDefinition | ConvertTo-Json -Depth 20
        $schemaPath = Join-Path -Path $script:testRoot -ChildPath 'schemas/application-manifest.schema.json'
        Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction Stop | Should -Be $true
    }

    It 'preserves source provider settings without adding provider-specific Core branches' {
        $result = & (Get-Module Wintainium.Core) {
            param($source, $policy)
            New-WintainiumApplicationDefinitionFromSource -Source $source -Policy $policy -OperationId 'model-test-4'
        } $script:source $script:policy

        $result.ApplicationDefinition.Source.settings.repository | Should -Be 'microsoft/PowerToys'
        $result.ApplicationDefinition.Id | Should -Be 'github.microsoft.powertoys'
    }
}