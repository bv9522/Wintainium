BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:schemaPath = Join-Path -Path $script:testRoot -ChildPath 'schemas/application-manifest.schema.json'
    $script:fixturePath = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Manifests/valid-portable-zip.json'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium manifest discovery' {
    BeforeEach {
        $script:collectionRoot = Join-Path -Path $TestDrive -ChildPath 'manifests'
        New-Item -ItemType Directory -Path $script:collectionRoot | Out-Null
    }

    It 'returns recognized manifest files in deterministic full-path order' {
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $script:collectionRoot 'zeta.wintainium.json')
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $script:collectionRoot 'alpha.wintainium.json')
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $script:collectionRoot 'middle.wintainium.json')

        $result = Get-WintainiumManifest -Path $script:collectionRoot

        $result.Candidates | Should -HaveCount 3
        $result.Candidates | Should -Be ($result.Candidates | Sort-Object)
    }

    It 'does not recurse unless Recurse is specified' {
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $script:collectionRoot 'root.wintainium.json')
        $nested = Join-Path $script:collectionRoot 'nested'
        New-Item -ItemType Directory -Path $nested | Out-Null
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $nested 'nested.wintainium.json')

        $result = Get-WintainiumManifest -Path $script:collectionRoot

        $result.Candidates | Should -HaveCount 1
        $result.Candidates[0] | Should -Match 'root\.wintainium\.json$'
    }

    It 'discovers nested manifests when Recurse is specified' {
        $nested = Join-Path $script:collectionRoot 'nested'
        New-Item -ItemType Directory -Path $nested | Out-Null
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $nested 'nested.wintainium.json')

        $result = Get-WintainiumManifest -Path $script:collectionRoot -Recurse

        $result.Candidates | Should -HaveCount 1
        $result.Candidates[0] | Should -Match 'nested\.wintainium\.json$'
    }

    It 'ignores arbitrary JSON and other unrecognized files' {
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $script:collectionRoot 'valid.wintainium.json')
        '{"not":"a manifest"}' | Set-Content -LiteralPath (Join-Path $script:collectionRoot 'catalog.json') -Encoding utf8
        'notes' | Set-Content -LiteralPath (Join-Path $script:collectionRoot 'README.txt') -Encoding utf8

        $result = Get-WintainiumManifest -Path $script:collectionRoot

        $result.Candidates | Should -HaveCount 1
        $result.Errors.Count | Should -Be 0
        $result.Warnings.Count | Should -Be 0
    }

    It 'imports discovered manifests and returns their models' {
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $script:collectionRoot 'neovim.wintainium.json')

        $result = Get-WintainiumManifest -Path $script:collectionRoot

        $result.IsSuccessful | Should -Be $true
        $result.Manifests | Should -HaveCount 1
        $result.Manifests[0].Id | Should -Be 'org.neovim.neovim'
        $result.Manifests[0].Name | Should -Be 'Neovim'
        $result.Errors.Count | Should -Be 0
    }

    It 'retains valid manifests when another candidate is malformed' {
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $script:collectionRoot 'valid.wintainium.json')
        '{ "manifestVersion": }' | Set-Content -LiteralPath (Join-Path $script:collectionRoot 'broken.wintainium.json') -Encoding utf8

        $result = Get-WintainiumManifest -Path $script:collectionRoot

        $result.IsSuccessful | Should -Be $false
        $result.Manifests | Should -HaveCount 1
        $result.Manifests[0].Id | Should -Be 'org.neovim.neovim'
        @($result.Errors.Code) | Should -Contain 'ManifestJsonInvalid'
    }

    It 'reports duplicate application IDs without selecting a winner' {
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $script:collectionRoot 'first.wintainium.json')
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $script:collectionRoot 'second.wintainium.json')

        $result = Get-WintainiumManifest -Path $script:collectionRoot

        $result.IsSuccessful | Should -Be $false
        $result.Manifests | Should -HaveCount 2
        @($result.Errors.Code) | Should -Contain 'ManifestDuplicateApplicationId'
    }

    It 'treats an empty recognized collection as successful' {
        $result = Get-WintainiumManifest -Path $script:collectionRoot

        $result.IsSuccessful | Should -Be $true
        $result.Candidates | Should -HaveCount 0
        $result.Manifests | Should -HaveCount 0
        $result.Errors.Count | Should -Be 0
    }

    It 'returns a structured error when the collection path is missing' {
        $missing = Join-Path $TestDrive 'missing-manifests'

        $result = Get-WintainiumManifest -Path $missing

        $result.IsSuccessful | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'ManifestCollectionNotFound'
    }

    It 'returns operation and log information without requiring network access' {
        Copy-Item -LiteralPath $script:fixturePath -Destination (Join-Path $script:collectionRoot 'offline.wintainium.json')

        $result = Get-WintainiumManifest -Path $script:collectionRoot

        $result.OperationId | Should -Not -BeNullOrEmpty
        $result.LogEvents.Count | Should -BeGreaterThan 0
        $result.IsSuccessful | Should -Be $true
    }
}
