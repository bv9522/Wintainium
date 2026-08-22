BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:fixtureRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Manifests'
    $script:schemaPath = Join-Path -Path $script:testRoot -ChildPath 'schemas/application-manifest.schema.json'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium manifest import' {
    It 'imports a valid manifest into the internal manifest model' {
        $path = Join-Path -Path $script:fixtureRoot -ChildPath 'valid-portable-zip.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $path; SchemaPath = $script:schemaPath } {
            Import-WintainiumManifest -Path $Path -SchemaPath $SchemaPath
        }

        $result.IsValid | Should -Be $true
        $result.Manifest | Should -Not -BeNullOrEmpty
        $result.Manifest.ManifestVersion | Should -Be '1.0'
        $result.Manifest.Id | Should -Be 'org.neovim.neovim'
        $result.Manifest.Name | Should -Be 'Neovim'
        $result.Errors.Count | Should -Be 0
        $result.Warnings.Count | Should -Be 0
    }

    It 'uses the bundled schema when SchemaPath is omitted' {
        $path = Join-Path -Path $script:fixtureRoot -ChildPath 'valid-portable-zip.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $path } {
            Import-WintainiumManifest -Path $Path
        }

        $result.IsValid | Should -Be $true
        $result.Manifest.Id | Should -Be 'org.neovim.neovim'
    }

    It 'returns ManifestFileNotFound for a missing file' {
        $path = Join-Path -Path $TestDrive -ChildPath 'does-not-exist.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $path; SchemaPath = $script:schemaPath } {
            Import-WintainiumManifest -Path $Path -SchemaPath $SchemaPath
        }

        $result.IsValid | Should -Be $false
        $result.Manifest | Should -BeNullOrEmpty
        @($result.Errors.Code) | Should -Contain 'ManifestFileNotFound'
    }

    It 'returns ManifestPathInvalid when Path is a directory' {
        $path = Join-Path -Path $TestDrive -ChildPath 'manifest-directory'
        New-Item -ItemType Directory -Path $path | Out-Null

        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $path; SchemaPath = $script:schemaPath } {
            Import-WintainiumManifest -Path $Path -SchemaPath $SchemaPath
        }

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'ManifestPathInvalid'
    }

    It 'returns ManifestJsonInvalid for malformed JSON' {
        $path = Join-Path -Path $TestDrive -ChildPath 'malformed.json'
        '{ "manifestVersion": }' | Set-Content -LiteralPath $path -Encoding utf8

        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $path; SchemaPath = $script:schemaPath } {
            Import-WintainiumManifest -Path $Path -SchemaPath $SchemaPath
        }

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'ManifestJsonInvalid'
    }

    It 'returns ManifestSchemaInvalid for valid JSON that violates the schema' {
        $path = Join-Path -Path $TestDrive -ChildPath 'schema-invalid.json'
        '{ "manifestVersion": "2.0" }' | Set-Content -LiteralPath $path -Encoding utf8

        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $path; SchemaPath = $script:schemaPath } {
            Import-WintainiumManifest -Path $Path -SchemaPath $SchemaPath
        }

        $result.IsValid | Should -Be $false
        @($result.Errors.Code) | Should -Contain 'ManifestSchemaInvalid'
    }

    It 'preserves nested source, installer, release, and artifact data' {
        $path = Join-Path -Path $script:fixtureRoot -ChildPath 'valid-portable-zip.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $path; SchemaPath = $script:schemaPath } {
            Import-WintainiumManifest -Path $Path -SchemaPath $SchemaPath
        }

        $result.IsValid | Should -Be $true
        $result.Manifest.Source.pluginId | Should -Be 'Wintainium.provider.github-releases'
        $result.Manifest.Installer.pluginId | Should -Be 'Wintainium.installer.portable-zip'
        $result.Manifest.Release.channel | Should -Be 'stable'
        $result.Manifest.Artifact.formats | Should -Contain 'zip'
        $result.Manifest.Artifact.architectures | Should -Contain 'x64'
    }

    It 'does not require network access to import a manifest' {
        $path = Join-Path -Path $script:fixtureRoot -ChildPath 'valid-portable-zip.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $path; SchemaPath = $script:schemaPath } {
            Import-WintainiumManifest -Path $Path -SchemaPath $SchemaPath
        }

        $result.IsValid | Should -Be $true
        $result.Errors.Count | Should -Be 0
    }
}
