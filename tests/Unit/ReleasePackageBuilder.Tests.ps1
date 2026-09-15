Describe 'Wintainium release package builder' {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $builderPath = Join-Path $repoRoot 'tools/New-WintainiumReleasePackage.ps1'
        $validatorPath = Join-Path $repoRoot 'tools/Test-WintainiumReleasePackage.ps1'
        $moduleManifestPath = Join-Path $repoRoot 'core/Wintainium.Core/Wintainium.Core.psd1'
    }

    It 'exists outside the distributable package boundary' {
        Test-Path -LiteralPath $builderPath -PathType Leaf | Should -BeTrue
    }

    It 'materializes the documented package layout from repository files' {
        $outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumPackageTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $outputRoot | Out-Null
        try {
            $result = & $builderPath -RepositoryRoot $repoRoot -OutputRoot $outputRoot
            $manifest = Import-PowerShellDataFile -LiteralPath $moduleManifestPath
            $packageRoot = Join-Path $outputRoot ('Wintainium-' + [string]$manifest.ModuleVersion)

            $result.IsSuccessful | Should -BeTrue
            $result.ModuleVersion | Should -Be $manifest.ModuleVersion
            $result.PackageRoot | Should -Be (Resolve-Path -LiteralPath $packageRoot).Path
            Test-Path -LiteralPath $result.ArchivePath -PathType Leaf | Should -BeTrue

            @(
                'ARCHITECTURE.md'
                'CHANGELOG.md'
                'PROJECT.md'
                'README.md'
                'ROADMAP.md'
                'core/Wintainium.Core/Wintainium.Core.psd1'
                'core/Wintainium.Core/Wintainium.Core.psm1'
                'docs/CLI.md'
                'schemas/application-manifest.schema.json'
                'manifests'
                'plugins'
            ) | ForEach-Object {
                $path = Join-Path $packageRoot $_
                $expectedType = if ($_ -in @('manifests', 'plugins')) { 'Container' } else { 'Leaf' }
                Test-Path -LiteralPath $path -PathType $expectedType | Should -BeTrue -Because $_
            }
        }
        finally {
            Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not copy development directories or repository placeholders' {
        $outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumPackageTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $outputRoot | Out-Null
        try {
            $result = & $builderPath -RepositoryRoot $repoRoot -OutputRoot $outputRoot
            $packageRoot = $result.PackageRoot

            @('.git', '.github', 'tests', '.editorconfig', '.gitignore', 'AI_CONTEXT.md', 'tools') | ForEach-Object {
                Test-Path -LiteralPath (Join-Path $packageRoot $_) | Should -BeFalse -Because $_
            }

            Test-Path -LiteralPath (Join-Path $packageRoot 'plugins/.gitkeep') | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $packageRoot 'manifests/.gitkeep') | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects a pre-existing package directory or archive instead of overwriting it' {
        $outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumPackageTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $outputRoot | Out-Null
        try {
            $manifest = Import-PowerShellDataFile -LiteralPath $moduleManifestPath
            $packageName = 'Wintainium-' + [string]$manifest.ModuleVersion
            $packageRoot = Join-Path $outputRoot $packageName
            New-Item -ItemType Directory -Path $packageRoot | Out-Null

            { & $builderPath -RepositoryRoot $repoRoot -OutputRoot $outputRoot } | Should -Throw '*already exists*'
        }
        finally {
            Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'assembles a package that independently passes release validation' {
        $outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumPackageTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $outputRoot | Out-Null
        try {
            $result = & $builderPath -RepositoryRoot $repoRoot -OutputRoot $outputRoot
            & $validatorPath -PackageRoot $result.PackageRoot | Select-Object -ExpandProperty IsValid | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'preflights required source assets before creating the package' {
        $sourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumSourceTest-' + [guid]::NewGuid().ToString('N'))
        $outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumPackageTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'core/Wintainium.Core') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'docs') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'manifests') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'plugins') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'schemas') -Force | Out-Null
        New-Item -ItemType Directory -Path $outputRoot | Out-Null
        try {
            { & $builderPath -RepositoryRoot $sourceRoot -OutputRoot $outputRoot } | Should -Throw '*required source asset*'
            Get-ChildItem -LiteralPath $outputRoot | Should -BeNullOrEmpty
        }
        finally {
            Remove-Item -LiteralPath $sourceRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'cleans up a partially assembled package after a post-creation failure' {
        $sourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumSourceTest-' + [guid]::NewGuid().ToString('N'))
        $outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumPackageTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'core/Wintainium.Core') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'docs') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'manifests') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'plugins') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot 'schemas') -Force | Out-Null
        New-Item -ItemType Directory -Path $outputRoot | Out-Null

        foreach ($relativePath in @(
            'ARCHITECTURE.md'
            'CHANGELOG.md'
            'PROJECT.md'
            'README.md'
            'ROADMAP.md'
            'docs/GettingStarted.md'
            'docs/CLI.md'
            'docs/ManifestAuthoring.md'
            'docs/Diagnostics.md'
            'docs/PublicResultContract.md'
            'docs/PublicPowerShellContract.md'
            'docs/ReleasePackaging.md'
            'core/Wintainium.Core/Wintainium.Core.psm1'
            'schemas/application-manifest.schema.json'
        )) {
            New-Item -ItemType File -Path (Join-Path $sourceRoot $relativePath) -Force | Out-Null
        }
        Copy-Item -LiteralPath $moduleManifestPath -Destination (Join-Path $sourceRoot 'core/Wintainium.Core/Wintainium.Core.psd1')
        New-Item -ItemType File -Path (Join-Path $sourceRoot 'tools') -Force | Out-Null

        try {
            { & $builderPath -RepositoryRoot $sourceRoot -OutputRoot $outputRoot } | Should -Throw
            Get-ChildItem -LiteralPath $outputRoot | Should -BeNullOrEmpty
        }
        finally {
            Remove-Item -LiteralPath $sourceRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
