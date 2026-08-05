$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
$schemaPath = Join-Path -Path $testRoot -ChildPath 'schemas/application-manifest.schema.json'
$fixtureRoot = Join-Path -Path $testRoot -ChildPath 'tests/Fixtures/Manifests'

Import-Module $modulePath -Force
$module = Get-Module Wintainium.Core

Describe 'Wintainium manifest validation' {
    It 'accepts a valid portable ZIP manifest against the shared schema' {
        $manifestPath = Join-Path -Path $fixtureRoot -ChildPath 'valid-portable-zip.json'
        $result = & $module {
            param($path, $schema)
            Test-WintainiumManifestSchema -ManifestPath $path -SchemaPath $schema
        } $manifestPath $schemaPath

        $result | Should Be $true
    }

    It 'rejects a manifest that is missing a required field' {
        $manifestPath = Join-Path -Path $fixtureRoot -ChildPath 'invalid-schema.json'
        $result = & $module {
            param($path, $schema)
            Test-WintainiumManifestSchema -ManifestPath $path -SchemaPath $schema
        } $manifestPath $schemaPath

        $result | Should Be $false
    }

    It 'reports prohibited manifest information during semantic validation' {
        $manifestPath = Join-Path -Path $fixtureRoot -ChildPath 'manifest-with-prohibited-key.json'
        $result = & $module {
            param($path)
            $loadResult = Import-WintainiumManifest -Path $path
            @($loadResult.Errors)
        } $manifestPath

        $result.Count | Should BeGreaterThan 0
        $result[0].Code | Should Be 'ManifestContainsProhibitedInformation'
    }
}
