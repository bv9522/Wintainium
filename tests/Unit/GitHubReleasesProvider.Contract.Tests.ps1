$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$harnessPath = Join-Path -Path $testRoot -ChildPath 'tests/Support/ProviderContractHarness.ps1'
. $harnessPath

$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
$providerRoot = Join-Path -Path $testRoot -ChildPath 'plugins'
$providerDirectory = Join-Path -Path $providerRoot -ChildPath 'Wintainium.provider.github-releases'
$providerDescriptorPath = Join-Path -Path $providerDirectory -ChildPath 'plugin.json'
$providerPath = Join-Path -Path $providerDirectory -ChildPath 'Wintainium.provider.github-releases.psm1'

Import-Module $modulePath -Force

Get-Module -Name 'Wintainium.provider.github-releases' -All |
    Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $providerPath -Force

if (-not (Test-Path -LiteralPath $providerDescriptorPath -PathType Leaf)) {
    throw "The GitHub Releases provider descriptor was not found at '$providerDescriptorPath'."
}

$descriptorResult = InModuleScope Wintainium.Core -Parameters @{ Path = $providerDescriptorPath } {
    Test-WintainiumPluginDescriptor -DescriptorPath $Path
}

if (-not $descriptorResult.IsValid) {
    $messages = @($descriptorResult.Errors | ForEach-Object { "$($_.Code): $($_.Message)" }) -join '; '
    throw "The GitHub Releases provider descriptor is invalid: $messages"
}

$script:provider = [pscustomobject][ordered]@{
    PluginId = $descriptorResult.Descriptor.pluginId
    PluginType = $descriptorResult.Descriptor.pluginType
    ContractVersions = @($descriptorResult.Descriptor.contractVersions)
    EntryPoint = $descriptorResult.Descriptor.entryPoint
    Capabilities = $descriptorResult.Descriptor.capabilities
    DescriptorPath = $providerDescriptorPath
}

BeforeAll {
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
