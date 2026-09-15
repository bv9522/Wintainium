Describe 'Wintainium release package validator' {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $validatorPath = Join-Path $repoRoot 'tools/Test-WintainiumReleasePackage.ps1'
        $moduleManifestPath = Join-Path $repoRoot 'core/Wintainium.Core/Wintainium.Core.psd1'
        $modulePath = Join-Path $repoRoot 'core/Wintainium.Core/Wintainium.Core.psm1'

        function New-ValidReleasePackageFixture {
            param([string]$Root)

            @(
                'core/Wintainium.Core'
                'docs'
                'manifests'
                'plugins'
                'schemas'
            ) | ForEach-Object {
                New-Item -ItemType Directory -Path (Join-Path $Root $_) -Force | Out-Null
            }

            @(
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
            ) | ForEach-Object {
                $target = Join-Path $Root $_
                New-Item -ItemType File -Path $target -Force | Out-Null
            }

            Copy-Item -LiteralPath $moduleManifestPath -Destination (Join-Path $Root 'core/Wintainium.Core/Wintainium.Core.psd1')
        }
    }

    It 'exists outside the distributable package boundary' {
        Test-Path -LiteralPath $validatorPath -PathType Leaf | Should -BeTrue
        $validatorPath | Should -Match '[\\/]tools[\\/]Test-WintainiumReleasePackage\.ps1$'
    }

    It 'accepts a complete release layout' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumReleaseTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        try {
            New-ValidReleasePackageFixture -Root $tempRoot
            & $validatorPath -PackageRoot $tempRoot | Select-Object -ExpandProperty IsValid | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects a package containing development directories' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumReleaseTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        try {
            New-ValidReleasePackageFixture -Root $tempRoot
            New-Item -ItemType Directory -Path (Join-Path $tempRoot 'tests') -Force | Out-Null
            { & $validatorPath -PackageRoot $tempRoot } | Should -Throw '*development directory*tests*'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects a package with an unsupported public export surface' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumReleaseTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        try {
            New-ValidReleasePackageFixture -Root $tempRoot
            $manifestPath = Join-Path $tempRoot 'core/Wintainium.Core/Wintainium.Core.psd1'
            $content = Get-Content -LiteralPath $manifestPath -Raw
            $content = $content -replace "'Get-WintainiumApplicationRelease'", "'Get-WintainiumApplicationRelease'`n        'Invoke-WintainiumSomething'"
            Set-Content -LiteralPath $manifestPath -Value $content
            { & $validatorPath -PackageRoot $tempRoot } | Should -Throw '*exported public command surface*'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects unexpected root development or repository entries' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumReleaseTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        try {
            New-ValidReleasePackageFixture -Root $tempRoot
            New-Item -ItemType File -Path (Join-Path $tempRoot 'AI_CONTEXT.md') -Force | Out-Null
            { & $validatorPath -PackageRoot $tempRoot } | Should -Throw '*unexpected root entry*AI_CONTEXT.md*'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects a package missing a required runtime directory' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumReleaseTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        try {
            New-ValidReleasePackageFixture -Root $tempRoot
            Remove-Item -LiteralPath (Join-Path $tempRoot 'plugins') -Recurse -Force
            { & $validatorPath -PackageRoot $tempRoot } | Should -Throw '*required package directory*plugins*'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
