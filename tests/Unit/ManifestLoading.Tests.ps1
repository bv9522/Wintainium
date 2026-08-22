BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:fixtureRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Manifests'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium manifest loading' {
    It 'loads a valid manifest into the internal manifest model' {
        $path = Join-Path -Path $script:fixtureRoot -ChildPath 'valid-portable-zip.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $path } {
            Import-WintainiumManifest -Path $Path
        }

        $result.IsValid | Should -Be $true
        $result.Manifest.Id | Should -Be 'org.neovim.neovim'
        ($result.Manifest.Artifact.formats -contains 'zip') | Should -Be $true
        $result.Errors.Count | Should -Be 0
    }

    It 'returns a structured error for a missing required property' {
        $path = Join-Path -Path $script:fixtureRoot -ChildPath 'invalid-schema.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $path } {
            Import-WintainiumManifest -Path $Path
        }

        $result.IsValid | Should -Be $false
        $result.Errors[0].Code | Should -Be 'ManifestSchemaInvalid'
    }

    It 'returns a structured error for a schema-invalid manifest' {
        $invalidManifest = Join-Path -Path $TestDrive -ChildPath 'schema-invalid.json'
        @'
{
  "manifestVersion": "2.0"
}
'@ | Set-Content -LiteralPath $invalidManifest -Encoding utf8

        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $invalidManifest } {
            Import-WintainiumManifest -Path $Path
        }

        $result.IsValid | Should -Be $false
        $result.Errors[0].Code | Should -Be 'ManifestSchemaInvalid'
    }

    It 'returns a structured error for malformed JSON' {
        $malformedManifest = Join-Path -Path $TestDrive -ChildPath 'malformed.json'
        '{ "id": }' | Set-Content -LiteralPath $malformedManifest -Encoding utf8

        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $malformedManifest } {
            Import-WintainiumManifest -Path $Path
        }

        $result.IsValid | Should -Be $false
        $result.Errors[0].Code | Should -Be 'ManifestJsonInvalid'
    }

    It 'discovers no manifests in an empty directory' {
        $emptyDirectory = Join-Path -Path $TestDrive -ChildPath 'empty'
        New-Item -ItemType Directory -Path $emptyDirectory | Out-Null

        $paths = InModuleScope Wintainium.Core -Parameters @{ Path = $emptyDirectory } {
            @(Find-WintainiumManifestFile -ManifestRoot $Path)
        }

        $paths.Count | Should -Be 0
    }

    It 'discovers multiple manifests from one local collection' {
        $manifestDirectory = Join-Path -Path $TestDrive -ChildPath 'many'
        New-Item -ItemType Directory -Path $manifestDirectory | Out-Null
        Copy-Item -LiteralPath (Join-Path -Path $script:fixtureRoot -ChildPath 'valid-portable-zip.json') -Destination (Join-Path -Path $manifestDirectory -ChildPath 'one.json')
        Copy-Item -LiteralPath (Join-Path -Path $script:fixtureRoot -ChildPath 'valid-msi.json') -Destination (Join-Path -Path $manifestDirectory -ChildPath 'two.json')

        $paths = InModuleScope Wintainium.Core -Parameters @{ Path = $manifestDirectory } {
            @(Find-WintainiumManifestFile -ManifestRoot $Path)
        }

        $paths.Count | Should -Be 2
        $paths[0] | Should -Match 'one.json$'
        $paths[1] | Should -Match 'two.json$'
    }
}
