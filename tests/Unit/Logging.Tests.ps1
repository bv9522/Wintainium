$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

Import-Module $modulePath -Force
$module = Get-Module Wintainium.Core

Describe 'Wintainium structured logging' {
    It 'creates a structured event with correlation data' {
        $event = & $module {
            New-WintainiumLogEvent -Severity Information -OperationId 'operation-123' -Component Core -EventName ValidationStarted -Message 'Started.' -Context @{ ManifestId = 'org.example.app' }
        }

        $event.OperationId | Should Be 'operation-123'
        $event.Component | Should Be 'Core'
        $event.Context.ManifestId | Should Be 'org.example.app'
    }
}
