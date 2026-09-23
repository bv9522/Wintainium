BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force
}

Describe 'Wintainium application onboarding' {
    BeforeEach {
        $script:manifestRoot = Join-Path -Path $TestDrive -ChildPath ("manifests-" + [guid]::NewGuid().Guid)
        $script:pluginRoot = Join-Path -Path $TestDrive -ChildPath ("plugins-" + [guid]::NewGuid().Guid)
        $githubPluginSource = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.provider.github-releases'
        $githubPluginTarget = Join-Path -Path $script:pluginRoot -ChildPath 'Wintainium.provider.github-releases'
        New-Item -ItemType Directory -Path $githubPluginTarget -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $githubPluginSource 'plugin.json') -Destination $githubPluginTarget -Force
        Copy-Item -LiteralPath (Join-Path $githubPluginSource 'Wintainium.provider.github-releases.psm1') -Destination $githubPluginTarget -Force

        $installerFixture = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Plugins/ValidInstaller'
        $installerTarget = Join-Path -Path $script:pluginRoot -ChildPath 'Wintainium.installer.portable-zip'
        New-Item -ItemType Directory -Path $installerTarget -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $installerFixture 'plugin.json') -Destination $installerTarget -Force
        Copy-Item -LiteralPath (Join-Path $installerFixture 'Wintainium.installer.valid-fixture.psm1') -Destination $installerTarget -Force

        $reconciliationFixture = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Plugins/ValidReconciliation'
        $reconciliationTarget = Join-Path -Path $script:pluginRoot -ChildPath 'Wintainium.reconciliation.valid-fixture'
        New-Item -ItemType Directory -Path $reconciliationTarget -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $reconciliationFixture 'plugin.json') -Destination $reconciliationTarget -Force
        Copy-Item -LiteralPath (Join-Path $reconciliationFixture 'Wintainium.reconciliation.valid-fixture.psm1') -Destination $reconciliationTarget -Force

        $script:policy = [pscustomobject][ordered]@{
            Installer = [pscustomobject][ordered]@{PluginId='Wintainium.installer.test';RequiredContractVersion='1';Settings=@{}}
            Reconciliation = [pscustomobject][ordered]@{PluginId='Wintainium.reconciliation.test';RequiredContractVersion='1';Settings=@{}}
            Release = [pscustomobject][ordered]@{Channel='stable'}
            Artifact = [pscustomobject][ordered]@{Formats=@('exe');Architectures=@('x64');AllowUnknownArchitecture=$false}
        }
    }

    It 'is exposed as a documented public Core command' {
        (Get-Command Invoke-WintainiumApplicationOnboarding -Module Wintainium.Core).CommandType | Should -Be 'Function'
    }

    It 'resolves, normalizes, and persists a GitHub source' {
        $result = Invoke-WintainiumApplicationOnboarding -SourceUri 'https://github.com/PCSX2/pcsx2/releases/tag/v2.9.78' -ManifestRoot $script:manifestRoot -PluginRoot $script:pluginRoot -Policy $script:policy
        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Resolved'
        $result.ApplicationDefinition.Id | Should -Be 'github.pcsx2.pcsx2'
        $result.ApplicationDefinition.Source.pluginId | Should -Be 'Wintainium.provider.github-releases'
        $result.ApplicationDefinition.Source.settings.repository | Should -Be 'PCSX2/pcsx2'
        $result.ManifestPath | Should -Be (Join-Path $script:manifestRoot 'github.pcsx2.pcsx2.wintainium.json')
        Test-Path -LiteralPath $result.ManifestPath | Should -Be $true
    }

    It 'uses the Core-owned default policy when the caller supplies no policy' {
        $result = Invoke-WintainiumApplicationOnboarding -SourceUri 'https://github.com/PCSX2/pcsx2' -ManifestRoot $script:manifestRoot -PluginRoot $script:pluginRoot
        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Resolved'
        $result.ApplicationDefinition.Installer.pluginId | Should -Be 'Wintainium.installer.portable-zip'
        $result.ApplicationDefinition.Reconciliation.pluginId | Should -Be 'Wintainium.reconciliation.valid-fixture'
        @($result.ApplicationDefinition.Artifact.formats) | Should -Be @('zip')
        @($result.ApplicationDefinition.Artifact.architectures) | Should -Be @('x64','x86','arm64','neutral')
        $result.ApplicationDefinition.Release.channel | Should -Be 'stable'
    }

    It 'does not mutate persistence when source resolution fails' {
        $result = Invoke-WintainiumApplicationOnboarding -SourceUri 'https://example.invalid/software' -ManifestRoot $script:manifestRoot -PluginRoot $script:pluginRoot -Policy $script:policy
        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceUnsupported'
        $result.ManifestPath | Should -BeNullOrEmpty
        @(Get-ChildItem -LiteralPath $script:manifestRoot -Recurse -File -Filter '*.wintainium.json' -ErrorAction SilentlyContinue).Count | Should -Be 0
    }

    It 'rejects a non-HTTP source before provider resolution' {
        $result = Invoke-WintainiumApplicationOnboarding -SourceUri 'file:///C:/software.exe' -ManifestRoot $script:manifestRoot -PluginRoot $script:pluginRoot -Policy $script:policy
        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceInvalid'
        @($result.Errors.Code) | Should -Contain 'SourceResolutionUriInvalid'
        $result.ManifestPath | Should -BeNullOrEmpty
    }

    It 'does not persist when Core policy normalization fails' {
        $invalidPolicy = [pscustomobject][ordered]@{Release=[pscustomobject]@{Channel='invalid'}}
        $result = Invoke-WintainiumApplicationOnboarding -SourceUri 'https://github.com/PCSX2/pcsx2' -ManifestRoot $script:manifestRoot -PluginRoot $script:pluginRoot -Policy $invalidPolicy
        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'ApplicationDefinitionInvalid'
        $result.ManifestPath | Should -BeNullOrEmpty
        @(Get-ChildItem -LiteralPath $script:manifestRoot -Recurse -File -Filter '*.wintainium.json' -ErrorAction SilentlyContinue).Count | Should -Be 0
    }

    It 'does not allow multiple capable providers to silently select a source' {
        $githubPluginSource = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.provider.github-releases'
        $ambiguousPluginTarget = Join-Path -Path $script:pluginRoot -ChildPath 'Wintainium.provider.test-github-source-resolution'
        New-Item -ItemType Directory -Path $ambiguousPluginTarget -Force | Out-Null
        $githubDescriptor = Get-Content -LiteralPath (Join-Path $githubPluginSource 'plugin.json') -Raw | ConvertFrom-Json
        $githubDescriptor.pluginId = 'Wintainium.provider.test-github-source-resolution'
        $githubDescriptor | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $ambiguousPluginTarget 'plugin.json') -Encoding utf8
        Copy-Item -LiteralPath (Join-Path $githubPluginSource 'Wintainium.provider.github-releases.psm1') -Destination (Join-Path $ambiguousPluginTarget 'Wintainium.provider.github-releases.psm1') -Force
        $result = Invoke-WintainiumApplicationOnboarding -SourceUri 'https://github.com/PCSX2/pcsx2' -ManifestRoot $script:manifestRoot -PluginRoot $script:pluginRoot -Policy $script:policy
        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceAmbiguous'
        @($result.Errors.Code) | Should -Contain 'SourceResolutionAmbiguous'
        $result.ManifestPath | Should -BeNullOrEmpty
    }

    It 'preserves the caller operation correlation identifier' {
        $operationId = [guid]::NewGuid().ToString()
        $result = Invoke-WintainiumApplicationOnboarding -SourceUri 'https://github.com/PCSX2/pcsx2' -ManifestRoot $script:manifestRoot -PluginRoot $script:pluginRoot -Policy $script:policy -OperationId $operationId
        $result.OperationId | Should -Be $operationId
        $result.SourceResolution.Source.ProviderSettings.repository | Should -Be 'PCSX2/pcsx2'
    }
}
