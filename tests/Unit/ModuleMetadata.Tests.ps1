$repoRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $repoRoot
$moduleManifestPath = Join-Path $repoRoot 'core/Wintainium.Core/Wintainium.Core.psd1'

Describe 'Wintainium Core module metadata' {
    BeforeAll {
        $manifest = Import-PowerShellDataFile -Path $moduleManifestPath
    }

    It 'declares the expected module identity and version' {
        $manifest.RootModule | Should -Be 'Wintainium.Core.psm1'
        $manifest.ModuleVersion | Should -Be '0.1.0'
        $manifest.GUID | Should -Be '44450f8f-15fc-4d6a-83f6-5f30b0bc3a54'
    }

    It 'requires the supported minimum PowerShell version' {
        $manifest.PowerShellVersion | Should -Be '7.4'
    }

    It 'exports exactly the current public command surface' {
        @($manifest.FunctionsToExport) | Should -Be @(
            'Get-WintainiumManifest'
            'Test-WintainiumApplicationDefinition'
            'Get-WintainiumApplicationRelease'
        )
        @($manifest.CmdletsToExport) | Should -BeNullOrEmpty
        @($manifest.AliasesToExport) | Should -BeNullOrEmpty
    }

    It 'does not export module variables as part of the public contract' {
        @($manifest.VariablesToExport) | Should -BeNullOrEmpty
    }

    It 'describes the implemented engine rather than the historical foundation phase' {
        $manifest.Description | Should -Match 'manifest validation'
        $manifest.Description | Should -Match 'provider-backed release discovery'
        $manifest.Description | Should -Match 'downloads'
        $manifest.Description | Should -Match 'installation'
        $manifest.Description | Should -Match 'lifecycle orchestration'
    }
}
