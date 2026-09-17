$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'

Describe 'Wintainium public Core boundary' {
    BeforeAll {
        Import-Module $modulePath -Force
    }

    It 'exports only the established public Core commands' {
        $exported = @(Get-Command -Module Wintainium.Core | Select-Object -ExpandProperty Name | Sort-Object)
        $exported | Should -Be @(
            'Get-WintainiumApplicationRelease'
            'Get-WintainiumManifest'
            'Test-WintainiumApplicationDefinition'
        )
    }

    It 'does not expose the internal application update lifecycle as a public command' {
        @(Get-Command Invoke-WintainiumApplicationUpdateLifecycle -ErrorAction SilentlyContinue).Count | Should -Be 0
    }
}
