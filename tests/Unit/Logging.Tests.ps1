$testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintanium.Core/Wintanium.Core.psd1'

Import-Module $modulePath -Force
$module = Get-Module Wintanium.Core

Describe 'Wintanium structured logging' {
    It 'creates a structured event with correlation data' {
        $event = & $module {
            New-WintaniumLogEvent -Severity Information -OperationId 'operation-123' -Component Core -EventName ValidationStarted -Message 'Started.' -Context @{ ManifestId = 'org.example.app' }
        }

        $event.OperationId | Should Be 'operation-123'
        $event.Component | Should Be 'Core'
        $event.Context.ManifestId | Should Be 'org.example.app'
    }
}
