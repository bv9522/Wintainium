$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
$providerRoot = Join-Path -Path $testRoot -ChildPath 'tests/Fixtures/ProviderContracts'
$harnessPath = Join-Path -Path $testRoot -ChildPath 'tests/Support/ProviderContractHarness.ps1'

Import-Module $modulePath -Force

# Pester discovers the dynamically registered contract tests while it is
a# evaluating the Describe block, so the harness function must exist before
the # discovery reaches Register-WintainiumProviderContractTests.
. $harnessPath

Describe 'Wintainium provider contract harness' {
    BeforeAll {
        $script:registry = InModuleScope Wintainium.Core -Parameters @{ Path = $providerRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }

        $script:provider = $script:registry.Plugins |
            Where-Object { $_.PluginType -eq 'Provider' -and $_.PluginId -eq 'Wintainium.provider.contract-fixture' }
    }

    Register-WintainiumProviderContractTests -Provider $script:provider
}
