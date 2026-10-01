BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force

    It 'omits null optional homepage and publisher properties from the persisted definition' {
        InModuleScope Wintainium.Core {
            $source = [pscustomobject][ordered]@{
                ApplicationId='example.application'
                Name='Example'
                CanonicalUri='https://example.com'
                Homepage=$null
                Publisher=$null
                ProviderId='Wintainium.provider.example'
                ProviderContractVersion='1'
                ProviderSettings=@{}
            }
            $policy = [pscustomobject][ordered]@{
                Installer=[pscustomobject]@{PluginId='example.installer';RequiredContractVersion='1';Settings=@{}}
                Reconciliation=[pscustomobject]@{PluginId='example.reconciliation';RequiredContractVersion='1';Settings=@{}}
                Release=[pscustomobject]@{Channel='stable'}
                Artifact=[pscustomobject]@{Formats=@('exe');Architectures=@('x64');AllowUnknownArchitecture=$false}
            }

            $result = New-WintainiumApplicationDefinitionFromSource -Source $source -Policy $policy
            $result.IsSuccessful | Should -Be $true
            $result.ApplicationDefinition.PSObject.Properties.Name | Should -Not -Contain 'homepage'
            $result.ApplicationDefinition.PSObject.Properties.Name | Should -Not -Contain 'publisher'
        }
    }
}

Describe 'Wintainium automatic application icon discovery' {
    It 'persists a trusted automatic icon URI in the application definition' {
        InModuleScope Wintainium.Core {
            $source = [pscustomobject][ordered]@{
                ApplicationId='example.application'
                Name='Example'
                CanonicalUri='https://example.com'
                ProviderId='Wintainium.provider.example'
                ProviderContractVersion='1'
                ProviderSettings=@{}
            }
            $policy = [pscustomobject][ordered]@{
                Installer=[pscustomobject]@{PluginId='example.installer';RequiredContractVersion='1';Settings=@{}}
                Reconciliation=[pscustomobject]@{PluginId='example.reconciliation';RequiredContractVersion='1';Settings=@{}}
                Release=[pscustomobject]@{Channel='stable'}
                Artifact=[pscustomobject]@{Formats=@('exe');Architectures=@('x64');AllowUnknownArchitecture=$false}
            }

            $result = New-WintainiumApplicationDefinitionFromSource -Source $source -Policy $policy -AutomaticIconUri 'https://example.com/icon.png'
            $result.IsSuccessful | Should -Be $true
            $result.ApplicationDefinition.icon.automaticUri | Should -Be 'https://example.com/icon.png'
        }
    }

    It 'does not invent icon metadata when no trusted icon was discovered' {
        InModuleScope Wintainium.Core {
            $source = [pscustomobject][ordered]@{
                ApplicationId='example.application'
                Name='Example'
                CanonicalUri='https://example.com'
                ProviderId='Wintainium.provider.example'
                ProviderContractVersion='1'
                ProviderSettings=@{}
            }
            $policy = [pscustomobject][ordered]@{
                Installer=[pscustomobject]@{PluginId='example.installer';RequiredContractVersion='1';Settings=@{}}
                Reconciliation=[pscustomobject]@{PluginId='example.reconciliation';RequiredContractVersion='1';Settings=@{}}
                Release=[pscustomobject]@{Channel='stable'}
                Artifact=[pscustomobject]@{Formats=@('exe');Architectures=@('x64');AllowUnknownArchitecture=$false}
            }

            $result = New-WintainiumApplicationDefinitionFromSource -Source $source -Policy $policy
            $result.IsSuccessful | Should -Be $true
            $result.ApplicationDefinition.PSObject.Properties.Name | Should -Not -Contain 'icon'
        }
    }
}
