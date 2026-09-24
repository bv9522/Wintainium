BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Parent $PSScriptRoot) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:pluginSource = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Plugins'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium public application release command' {
    BeforeEach {
        $script:pluginRoot = Join-Path $TestDrive ("plugins-" + [guid]::NewGuid().Guid)
        $script:manifestRoot = Join-Path $TestDrive ("manifests-" + [guid]::NewGuid().Guid)

        $providerTarget = Join-Path $script:pluginRoot 'Wintainium.provider.github-releases'
        $installerTarget = Join-Path $script:pluginRoot 'Wintainium.installer.portable-zip'
        $reconciliationTarget = Join-Path $script:pluginRoot 'Wintainium.reconciliation.valid-fixture'

        New-Item -ItemType Directory -Path $providerTarget, $installerTarget, $reconciliationTarget -Force | Out-Null

        Copy-Item (Join-Path $script:pluginSource 'ValidProvider/plugin.json') $providerTarget -Force
        Copy-Item (Join-Path $script:pluginSource 'ValidProvider/Wintainium.provider.valid-fixture.psm1') $providerTarget -Force
        Copy-Item (Join-Path $script:pluginSource 'ValidInstaller/plugin.json') $installerTarget -Force
        Copy-Item (Join-Path $script:pluginSource 'ValidReconciliation/plugin.json') $reconciliationTarget -Force
        Copy-Item (Join-Path $script:pluginSource 'ValidReconciliation/Wintainium.reconciliation.valid-fixture.psm1') $reconciliationTarget -Force

        $script:manifestPath = Join-Path $script:manifestRoot 'example.wintainium.json'
        New-Item -ItemType Directory -Path $script:manifestRoot -Force | Out-Null

        [ordered]@{
            manifestVersion = '1.1'
            id = 'org.example.release-test'
            name = 'Release Test'
            source = [ordered]@{
                pluginId = 'Wintainium.provider.github-releases'
                requiredContractVersion = '1'
                settings = @{}
            }
            installer = [ordered]@{
                pluginId = 'Wintainium.installer.portable-zip'
                requiredContractVersion = '1'
                settings = @{}
            }
            reconciliation = [ordered]@{
                pluginId = 'Wintainium.reconciliation.valid-fixture'
                requiredContractVersion = '1'
                settings = @{}
            }
            release = [ordered]@{ channel = 'stable' }
            artifact = [ordered]@{
                formats = @('zip')
                architectures = @('x64')
                allowUnknownArchitecture = $false
            }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:manifestPath -Encoding utf8
    }

    It 'is exposed as a documented public Core command' {
        (Get-Command Get-WintainiumApplicationRelease -Module Wintainium.Core).CommandType | Should -Be 'Function'
    }

    It 'returns a structured release result with Core operation correlation' {
        $operationId = [guid]::NewGuid().ToString()
        $result = Get-WintainiumApplicationRelease -ManifestPath $script:manifestPath -PluginRoot $script:pluginRoot -OperationId $operationId

        $result.OperationId | Should -Be $operationId
        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        $result.Manifest.Id | Should -Be 'org.example.release-test'
        $result.ProviderPlugin.PluginId | Should -Be 'Wintainium.provider.github-releases'
        $result.Releases.Count | Should -Be 1
        $result.Releases[0].ReleaseId | Should -Be 'fixture-release-1'
        $result.Releases[0].Version | Should -Be '1.2.3'
        $result.Releases[0].Channel | Should -Be 'stable'
        $result.Releases[0].Artifacts.Count | Should -Be 1
        $result.Releases[0].Artifacts[0].Architecture | Should -Be 'x64'
        @($result.Errors).Count | Should -Be 0
    }

    It 'preserves a successful no-release observation without inventing a release' {
        $manifest = Get-Content -LiteralPath $script:manifestPath -Raw | ConvertFrom-Json
        $manifest.source.settings = [pscustomobject]@{ mode = 'empty' }
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:manifestPath -Encoding utf8

        $result = Get-WintainiumApplicationRelease -ManifestPath $script:manifestPath -PluginRoot $script:pluginRoot

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'NoReleasesFound'
        @($result.Releases).Count | Should -Be 0
        @($result.Errors).Count | Should -Be 0
    }

    It 'returns provider failures as structured release-discovery failures' {
        $manifest = Get-Content -LiteralPath $script:manifestPath -Raw | ConvertFrom-Json
        $manifest.source.settings = [pscustomobject]@{ mode = 'throw' }
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:manifestPath -Encoding utf8

        $result = Get-WintainiumApplicationRelease -ManifestPath $script:manifestPath -PluginRoot $script:pluginRoot

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ProviderInternalError'
        @($result.Errors.Code) | Should -Contain 'ProviderInternalError'
        $result.Releases.Count | Should -Be 0
    }

    It 'rejects an invalid operation identifier through the Core validation boundary' {
        $result = Get-WintainiumApplicationRelease -ManifestPath $script:manifestPath -PluginRoot $script:pluginRoot -OperationId 'not-a-guid'

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ApplicationDefinitionInvalid'
        @($result.Errors.Code) | Should -Contain 'OperationIdInvalid'
        $result.Releases.Count | Should -Be 0
    }

    It 'does not expose malformed provider releases to the public result' {
        $manifest = Get-Content -LiteralPath $script:manifestPath -Raw | ConvertFrom-Json
        $manifest.source.settings = [pscustomobject]@{ mode = 'bad-release' }
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:manifestPath -Encoding utf8

        $result = Get-WintainiumApplicationRelease -ManifestPath $script:manifestPath -PluginRoot $script:pluginRoot

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ProviderResultInvalid'
        @($result.Errors.Code) | Should -Contain 'ProviderResultReleaseInvalid'
        $result.Releases.Count | Should -Be 0
    }
}
