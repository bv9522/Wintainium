$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$harnessPath = Join-Path -Path $testRoot -ChildPath 'tests/Support/ProviderContractHarness.ps1'
. $harnessPath

BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:providerRoot = Join-Path -Path $script:testRoot -ChildPath 'plugins'
    $script:providerPath = Join-Path -Path $script:providerRoot -ChildPath 'Wintainium.provider.github-releases/Wintainium.provider.github-releases.psm1'

    Import-Module $script:modulePath -Force

    Get-Module -Name 'Wintainium.provider.github-releases' -All |
        Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $script:providerPath -Force

    Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod {
        @([pscustomobject]@{
            id = 9001
            tag_name = 'v9.0.0'
            prerelease = $false
            published_at = '2026-08-01T12:00:00Z'
            assets = @(
                [pscustomobject]@{
                    browser_download_url = 'https://github.com/example/project/releases/download/v9.0.0/example-9.0.0-x64.zip'
                    name = 'example-9.0.0-x64.zip'
                    size = 4096
                }
            )
        })
    }

    $script:registry = InModuleScope Wintainium.Core -Parameters @{ Path = $script:providerRoot } {
        Get-WintainiumPluginRegistry -PluginRoot $Path
    }

    $script:provider = $script:registry.Plugins |
        Where-Object {
            $_.PluginType -eq 'Provider' -and
            $_.PluginId -eq 'Wintainium.provider.github-releases'
        } |
        Select-Object -First 1

    if (-not $script:provider) {
        throw "The GitHub Releases provider could not be resolved from '$script:providerRoot'."
    }
}

Describe 'Wintainium GitHub Releases provider contract harness' {
    $requestFactory = {
        [pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            ApplicationId = 'example.application'
            ProviderId = $script:provider.PluginId
            RequiredContractVersion = '1'
            Settings = @{ repository = 'example/project' }
            DiscoveryContext = @{}
        }
    }

    Register-WintainiumProviderContractTests -Provider $script:provider -RequestFactory $requestFactory
}
