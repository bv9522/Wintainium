Describe 'Wintainium release packaging boundary' {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $moduleManifestPath = Join-Path $repoRoot 'core/Wintainium.Core/Wintainium.Core.psd1'
        $releasePackagingPath = Join-Path $repoRoot 'docs/ReleasePackaging.md'
        $manifest = Import-PowerShellDataFile -Path $moduleManifestPath
    }

    It 'uses the Core module manifest as the authoritative version source' {
        $manifest.ModuleVersion | Should -Be '0.1.0'
        $manifest.ModuleVersion | Should -Match '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$'
        Test-Path -LiteralPath $releasePackagingPath -PathType Leaf | Should -BeTrue
        Get-Content -LiteralPath $releasePackagingPath -Raw | Should -Match 'Core module manifest is the authoritative version source'
    }

    It 'contains the required release boundary documentation assets' {
        @(
            'README.md'
            'PROJECT.md'
            'ARCHITECTURE.md'
            'ROADMAP.md'
            'CHANGELOG.md'
            'docs/GettingStarted.md'
            'docs/CLI.md'
            'docs/ManifestAuthoring.md'
            'docs/Diagnostics.md'
            'docs/PublicResultContract.md'
            'docs/PublicApplicationUpdateResult.md'
            'docs/PublicPowerShellContract.md'
            'docs/ReleasePackaging.md'
            'core/Wintainium.Core/Wintainium.Core.psd1'
            'core/Wintainium.Core/Wintainium.Core.psm1'
            'schemas/application-manifest.schema.json'
        ) | ForEach-Object {
            Test-Path -LiteralPath (Join-Path $repoRoot $_) -PathType Leaf | Should -BeTrue -Because $_
        }
    }

    It 'documents the development-only material excluded from a distributable package' {
        $content = Get-Content -LiteralPath $releasePackagingPath -Raw

        $content | Should -Match '`\.git/`'
        $content | Should -Match '`\.github/`'
        $content | Should -Match '`tests/`'
        $content | Should -Match 'Pester output'
        $content | Should -Match 'local user configuration, application state, caches, logs'
    }

    It 'keeps release validation separate from execution and user-state mutation' {
        $content = Get-Content -LiteralPath $releasePackagingPath -Raw

        $content | Should -Match 'does not install software'
        $content | Should -Match 'contact upstream providers'
        $content | Should -Match 'mutate user state'
    }

    It 'requires the supported public command surface in release validation' {
        @($manifest.FunctionsToExport) | Should -Be @(
            'Get-WintainiumManifest'
            'Test-WintainiumApplicationDefinition'
            'Get-WintainiumApplicationRelease'
            'Invoke-WintainiumApplicationUpdate'
        )
    }
}