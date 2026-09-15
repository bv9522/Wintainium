Describe 'Wintainium engine upgrade transaction' {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $builderPath = Join-Path $repoRoot 'tools/New-WintainiumReleasePackage.ps1'
        $upgradePath = Join-Path $repoRoot 'tools/Invoke-WintainiumEngineUpgrade.ps1'
    }

    It 'exists outside the distributable package boundary' {
        Test-Path -LiteralPath $upgradePath -PathType Leaf | Should -BeTrue
    }

    It 'validates, stages, switches, and removes obsolete program files while preserving durable data outside the program root' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumUpgradeTest-' + [guid]::NewGuid().ToString('N'))
        $outputRoot = Join-Path $root 'release'
        $programRoot = Join-Path $root 'program'
        $dataRoot = Join-Path $root 'data'
        New-Item -ItemType Directory -Path $outputRoot, $programRoot, $dataRoot -Force | Out-Null
        try {
            Set-Content -LiteralPath (Join-Path $programRoot 'obsolete.txt') -Value 'old program' -NoNewline
            $durableState = Join-Path $dataRoot 'installed-state.json'
            Set-Content -LiteralPath $durableState -Value '{"SchemaVersion":1,"States":[]}' -NoNewline

            $packageResult = & $builderPath -RepositoryRoot $repoRoot -OutputRoot $outputRoot
            $result = & $upgradePath -PackageRoot $packageResult.PackageRoot -ProgramRoot $programRoot

            $result.IsSuccessful | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $programRoot 'core/Wintainium.Core/Wintainium.Core.psd1') -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $programRoot 'obsolete.txt') | Should -BeFalse
            Test-Path -LiteralPath $durableState -PathType Leaf | Should -BeTrue
            Get-ChildItem -LiteralPath $root -Force | Where-Object Name -like '.program-upgrade-*' | Should -BeNullOrEmpty
            Get-ChildItem -LiteralPath $root -Force | Where-Object Name -like '.program-backup-*' | Should -BeNullOrEmpty
        }
        finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects an invalid incoming package before changing the existing program' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumUpgradeTest-' + [guid]::NewGuid().ToString('N'))
        $packageRoot = Join-Path $root 'package'
        $programRoot = Join-Path $root 'program'
        New-Item -ItemType Directory -Path $packageRoot, $programRoot -Force | Out-Null
        try {
            Set-Content -LiteralPath (Join-Path $programRoot 'sentinel.txt') -Value 'old program' -NoNewline
            Set-Content -LiteralPath (Join-Path $packageRoot 'invalid.txt') -Value 'not a release' -NoNewline

            { & $upgradePath -PackageRoot $packageRoot -ProgramRoot $programRoot } | Should -Throw '*release validation*'
            Get-Content -LiteralPath (Join-Path $programRoot 'sentinel.txt') | Should -Be 'old program'
            Get-ChildItem -LiteralPath $root -Force | Where-Object Name -like '.program-*' | Should -BeNullOrEmpty
        }
        finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects a missing existing program root before staging anything' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumUpgradeTest-' + [guid]::NewGuid().ToString('N'))
        $outputRoot = Join-Path $root 'release'
        $missingProgramRoot = Join-Path $root 'missing-program'
        New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
        try {
            $packageResult = & $builderPath -RepositoryRoot $repoRoot -OutputRoot $outputRoot
            { & $upgradePath -PackageRoot $packageResult.PackageRoot -ProgramRoot $missingProgramRoot } | Should -Throw '*does not exist*'
            Get-ChildItem -LiteralPath $root -Force | Where-Object Name -like '.missing-program-*' | Should -BeNullOrEmpty
        }
        finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects package and program roots that contain one another' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ('WintainiumUpgradeTest-' + [guid]::NewGuid().ToString('N'))
        $programRoot = Join-Path $root 'program'
        $packageRoot = Join-Path $programRoot 'package'
        New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
        try {
            { & $upgradePath -PackageRoot $packageRoot -ProgramRoot $programRoot } | Should -Throw '*must not contain one another*'
        }
        finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
