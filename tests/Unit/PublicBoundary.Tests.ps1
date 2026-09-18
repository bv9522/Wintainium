Describe 'Wintainium public Core boundary' {
    BeforeAll {
        $script:testRoot = Split-Path -Path (Split-Path -Parent $PSScriptRoot) -Parent
        $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
        Import-Module $script:modulePath -Force
    }

    It 'exports only the established public Core commands' {
        $exported = @(Get-Command -Module Wintainium.Core | Select-Object -ExpandProperty Name | Sort-Object)
        $exported | Should -Be @(
            'Get-WintainiumApplicationRelease'
            'Get-WintainiumManifest'
            'Invoke-WintainiumApplicationUpdate'
            'Test-WintainiumApplicationDefinition'
        )
    }

    It 'does not expose the internal application update lifecycle as a public command' {
        @(Get-Command Invoke-WintainiumApplicationUpdateLifecycle -ErrorAction SilentlyContinue).Count | Should -Be 0
    }

    It 'does not expose internal lifecycle dependencies through the public update command' {
        $command = Get-Command -Name Invoke-WintainiumApplicationUpdate -Module Wintainium.Core

        $command.Parameters.Keys | Should -Not -Contain 'OperationId'
        $command.Parameters.Keys | Should -Not -Contain 'HttpClient'
        $command.Parameters.Keys | Should -Not -Contain 'Request'
        $command.Parameters.Keys | Should -Not -Contain 'StagePlan'
        $command.Parameters.Keys | Should -Not -Contain 'StageFactory'
    }
}