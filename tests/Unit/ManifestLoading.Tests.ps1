$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
$fixtureRoot = Join-Path -Path $testRoot -ChildPath 'tests/Fixtures/Manifests'

Import-Module $modulePath -Force
$module = Get-Module Wintainium.Core

Describe 'Wintainium manifest loading' {
    It 'loads a valid manifest into the internal manifest model' {
        $result = & $module {
            param($path)
            Import-WintainiumManifest -Path $path
        } (Join-Path -Path $fixtureRoot -ChildPath 'valid-portable-zip.json')

        $result.IsValid | Should Be $true
        $result.Manifest.Id | Should Be 'org.neovim.neovim'
        ($result.Manifest.Artifact.formats -contains 'zip') | Should Be $true
        $result.Errors.Count | Should Be 0
    }

    It 'returns a structured error for a missing required property' {
        $result = & $module {
            param($path)
            Import-WintainiumManifest -Path $path
        } (Join-Path -Path $fixtureRoot -ChildPath 'invalid-schema.json')

        $result.IsValid | Should Be $false
        $result.Errors[0].Code | Should Be 'ManifestSchemaInvalid'
    }

    It 'returns a structured error for a schema-invalid manifest' {
        $invalidManifest = Join-Path -Path $TestDrive -ChildPath 'schema-invalid.json'
        @'
{
  "manifestVersion": "2.0"
}
'@ | Set-Content -LiteralPath $invalidManifest -Encoding utf8

        $result = & $module {
            param($path)
            Import-WintainiumManifest -Path $path
        } $invalidManifest

        $result.IsValid | Should Be $false
        $result.Errors[0].Code | Should Be 'ManifestSchemaInvalid'
    }

    It 'returns a structured error for malformed JSON' {
        $malformedManifest = Join-Path -Path $TestDrive -ChildPath 'malformed.json'
        '{ "id": }' | Set-Content -LiteralPath $malformedManifest -Encoding utf8

        $result = & $module {
            param($path)
            Import-WintainiumManifest -Path $path
        } $malformedManifest

        $result.IsValid | Should Be $false
        $result.Errors[0].Code | Should Be 'ManifestJsonInvalid'
    }

    It 'discovers no manifests in an empty directory' {
        $emptyDirectory = Join-Path -Path $TestDrive -ChildPath 'empty'
        New-Item -ItemType Directory -Path $emptyDirectory | Out-Null

        $paths = & $module {
            param($path)
            @(Find-WintainiumManifestFile -ManifestRoot $path)
        } $emptyDirectory

        $paths.Count | Should Be 0
    }

    It 'discovers multiple manifests from one local collection' {
        $manifestDirectory = Join-Path -Path $TestDrive -ChildPath 'many'
        New-Item -ItemType Directory -Path $manifestDirectory | Out-Null
        Copy-Item -LiteralPath (Join-Path -Path $fixtureRoot -ChildPath 'valid-portable-zip.json') -Destination (Join-Path -Path $manifestDirectory -ChildPath 'one.json')
        Copy-Item -LiteralPath (Join-Path -Path $fixtureRoot -ChildPath 'valid-msi.json') -Destination (Join-Path -Path $manifestDirectory -ChildPath 'two.json')

        $paths = & $module {
            param($path)
            @(Find-WintainiumManifestFile -ManifestRoot $path)
        } $manifestDirectory

        $paths.Count | Should Be 2
        $paths[0] | Should Match 'one.json$'
        $paths[1] | Should Match 'two.json$'
    }
}
