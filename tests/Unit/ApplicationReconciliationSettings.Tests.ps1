BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force
}

Describe 'Wintainium reconciliation settings boundary' {
    BeforeEach {
        $script:manifestRoot = Join-Path $TestDrive -ChildPath ("manifests-" + [guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $script:manifestRoot -Force | Out-Null

        $script:manifestPath = Join-Path $script:manifestRoot 'org.7-zip.7-zip.wintainium.json'
        $fixturePath = Join-Path $script:testRoot 'tests/Fixtures/Manifests/windows-7zip-reconciliation.json'
        Copy-Item -LiteralPath $fixturePath -Destination $script:manifestPath -Force

        $script:pluginRoot = Join-Path $TestDrive -ChildPath ("plugins-" + [guid]::NewGuid().Guid)
        $pluginSource = Join-Path $script:testRoot 'plugins/Wintainium.reconciliation.windows-installed-application'
        $pluginTarget = Join-Path $script:pluginRoot 'Wintainium.reconciliation.windows-installed-application'
        New-Item -ItemType Directory -Path $pluginTarget -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $pluginSource 'plugin.json') -Destination $pluginTarget -Force
        Copy-Item -LiteralPath (Join-Path $pluginSource 'Wintainium.reconciliation.windows-installed-application.psm1') -Destination $pluginTarget -Force
    }

    It 'is exposed as a documented public Core command' {
        (Get-Command Set-WintainiumApplicationReconciliationSettings -Module Wintainium.Core).CommandType | Should -Be 'Function'
    }

    It 'updates reconciliation settings through the Core manifest boundary' {
        $settings = [ordered]@{
            registry = [ordered]@{
                locations = @(
                    [ordered]@{ scope='machine'; view='64' },
                    [ordered]@{ scope='machine'; view='32' },
                    [ordered]@{ scope='user'; view='native' }
                )
                match = @(
                    [ordered]@{ value='subkey'; equals='7-Zip' }
                )
            }
        }

        $result = Set-WintainiumApplicationReconciliationSettings -ManifestPath $script:manifestPath -Settings $settings -PluginRoot $script:pluginRoot

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Updated'
        $result.ManifestPath | Should -Be $script:manifestPath
        $result.Manifest.reconciliation.pluginId | Should -Be 'Wintainium.reconciliation.windows-installed-application'
        $result.Manifest.reconciliation.settings.registry.match[0].equals | Should -Be '7-Zip'

        $persisted = Get-Content -LiteralPath $script:manifestPath -Raw | ConvertFrom-Json
        $persisted.reconciliation.settings.registry.match[0].equals | Should -Be '7-Zip'
    }

    It 'rejects scalar settings without mutating the manifest' {
        $before = Get-Content -LiteralPath $script:manifestPath -Raw

        $result = Set-WintainiumApplicationReconciliationSettings -ManifestPath $script:manifestPath -Settings '7-Zip' -PluginRoot $script:pluginRoot

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'InvalidSettings'
        @($result.Errors.Code) | Should -Contain 'ReconciliationSettingsInvalid'
        (Get-Content -LiteralPath $script:manifestPath -Raw) | Should -Be $before
    }

    It 'rejects an undeclared reconciliation plugin' {
        $manifest = Get-Content -LiteralPath $script:manifestPath -Raw | ConvertFrom-Json
        $manifest.reconciliation.pluginId = 'Wintainium.reconciliation.missing'
        $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $script:manifestPath -Encoding utf8

        $result = Set-WintainiumApplicationReconciliationSettings -ManifestPath $script:manifestPath -Settings @{ registry = @{} } -PluginRoot $script:pluginRoot

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'InvalidSettings'
        @($result.Errors.Code) | Should -Contain 'ReconciliationPluginUnavailable'
    }
}
