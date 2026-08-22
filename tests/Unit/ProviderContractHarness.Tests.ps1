BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:providerRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/ProviderContracts'
    $script:harnessPath = Join-Path -Path $script:testRoot -ChildPath 'tests/Support/ProviderContractHarness.ps1'

    Import-Module $script:modulePath -Force
    . $script:harnessPath
}

Describe 'Wintainium provider contract harness' {
    BeforeAll {
        $script:registry = InModuleScope Wintainium.Core -Parameters @{ Path = $script:providerRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }

        $script:provider = $script:registry.Plugins |
            Where-Object { $_.PluginType -eq 'Provider' -and $_.PluginId -eq 'Wintainium.provider.contract-fixture' }
    }

    Register-WintainiumProviderContractTests -Provider $script:provider
}
