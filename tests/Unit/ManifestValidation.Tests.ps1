BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:schemaPath = Join-Path -Path $script:testRoot -ChildPath 'schemas/application-manifest.schema.json'
    $script:fixtureRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Manifests'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium manifest validation' {
    It 'accepts a valid portable ZIP manifest against the shared schema' {
        $manifestPath = Join-Path -Path $script:fixtureRoot -ChildPath 'valid-portable-zip.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $manifestPath; Schema = $script:schemaPath } {
            Test-WintainiumManifestSchema -ManifestPath $Path -SchemaPath $Schema
        }

        $result | Should -Be $true
    }

    It 'rejects a manifest that is missing a required field' {
        $manifestPath = Join-Path -Path $script:fixtureRoot -ChildPath 'invalid-schema.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $manifestPath; Schema = $script:schemaPath } {
            Test-WintainiumManifestSchema -ManifestPath $Path -SchemaPath $Schema
        }

        $result | Should -Be $false
    }

    It 'reports prohibited manifest information during semantic validation' {
        $manifestPath = Join-Path -Path $script:fixtureRoot -ChildPath 'manifest-with-prohibited-key.json'
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $manifestPath } {
            $loadResult = Import-WintainiumManifest -Path $Path
            @($loadResult.Errors)
        }

        $result.Count | Should -BeGreaterThan 0
        $result[0].Code | Should -Be 'ManifestContainsProhibitedInformation'
    }
}
