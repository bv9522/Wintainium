Describe 'Wintainium release package validator' {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $validatorPath = Join-Path $repoRoot 'tools/Test-WintainiumReleasePackage.ps1'
        $moduleManifestPath = Join-Path $repoRoot 'core/Wintainium.Core/Wintainium.Core.psd1'
        $manifest = Import-PowerShellDataFile -LiteralPath $moduleManifestPath
    }

    It 'exists outside the distributable package boundary' {
        Test-Path -LiteralPath $validatorPath -PathType Leaf | Should -BeTrue
        $validatorPath | Should -Match '[\\/]tools[\\/]Test-WintainiumReleasePackage\.ps1$'
    }

    It 'accepts the repository runtime layout when development directories are excluded' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumReleaseTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        try {
            $requiredDirectories = @(
                'core/Wintainium.Core'
                'schemas'
            )
            $requiredDirectories | ForEach-Object { New-Item -ItemType Directory -Path (Join-Path $tempRoot $_) -Force | Out-Null }

            @(
                'README.md'
                'PROJECT.md'
                'ARCHITECTURE.md'
                'ROADMAP.md'
                'CHANGELOG.md'
                'core/Wintainium.Core/Wintainium.Core.psm1'
                'schemas/application-manifest.schema.json'
            ) | ForEach-Object {
                $target = Join-Path $tempRoot $_
                New-Item -ItemType File -Path $target -Force | Out-Null
            }

            Copy-Item -LiteralPath $moduleManifestPath -Destination (Join-Path $tempRoot 'core/Wintainium.Core/Wintainium.Core.psd1')
            & $validatorPath -PackageRoot $tempRoot | Select-Object -ExpandProperty IsValid | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects a package containing development directories' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumReleaseTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'tests') -Force | Out-Null
        try {
            { & $validatorPath -PackageRoot $tempRoot } | Should -Throw '*development directory*tests*'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects a package with an unsupported public export surface' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumReleaseTest-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'core/Wintainium.Core') -Force | Out-Null
        try {
            Copy-Item -LiteralPath $moduleManifestPath -Destination (Join-Path $tempRoot 'core/Wintainium.Core/Wintainium.Core.psd1')
            Copy-Item -LiteralPath (Join-Path $repoRoot 'core/Wintainium.Core/Wintainium.Core.psm1') -Destination (Join-Path $tempRoot 'core/Wintainium.Core/Wintainium.Core.psm1')
            $invalidManifest = Import-PowerShellDataFile -LiteralPath (Join-Path $tempRoot 'core/Wintainium.Core/Wintainium.Core.psd1')
            $invalidManifest.FunctionsToExport = @($manifest.FunctionsToExport + 'Invoke-WintainiumSomething')
            $invalidManifest | Out-String | Set-Content -LiteralPath (Join-Path $tempRoot 'invalid.txt')
            $content = Get-Content -LiteralPath (Join-Path $tempRoot 'core/Wintainium.Core/Wintainium.Core.psd1') -Raw
            $content = $content -replace "'Get-WintainiumApplicationRelease'", "'Get-WintainiumApplicationRelease'`n        'Invoke-WintainiumSomething'"
            Set-Content -LiteralPath (Join-Path $tempRoot 'core/Wintainium.Core/Wintainium.Core.psd1') -Value $content
            { & $validatorPath -PackageRoot $tempRoot } | Should -Throw '*exported public command surface*'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
