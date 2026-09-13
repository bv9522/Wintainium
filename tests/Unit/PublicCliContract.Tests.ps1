BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium public CLI contract' {
    It 'exports only the approved user-facing commands' {
        $commands = @(Get-Command -Module Wintainium.Core -CommandType Function | Select-Object -ExpandProperty Name | Sort-Object)

        $commands | Should -Be @(
            'Get-WintainiumApplicationRelease'
            'Get-WintainiumManifest'
            'Test-WintainiumApplicationDefinition'
        )
    }

    It 'does not export the low-level installer request helper' {
        Get-Command -Name New-WintainiumInstallerRequest -Module Wintainium.Core -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

    It 'retains the low-level installer request helper inside the loaded Core module scope' {
        $module = Get-Module -Name Wintainium.Core
        $module | Should -Not -BeNullOrEmpty

        $result = & $module {
            Get-Command -Name New-WintainiumInstallerRequest -CommandType Function -ErrorAction SilentlyContinue
        }

        $result | Should -Not -BeNullOrEmpty
    }

    It 'uses approved parameter naming on the public manifest command' {
        $command = Get-Command -Name Get-WintainiumManifest -Module Wintainium.Core
        $command.Parameters.Keys | Should -Contain 'Path'
        $command.Parameters.Keys | Should -Contain 'Recurse'
        $command.Parameters.Keys | Should -Contain 'SchemaPath'
    }

    It 'uses approved parameter naming on the public application validation command' {
        $command = Get-Command -Name Test-WintainiumApplicationDefinition -Module Wintainium.Core
        $command.Parameters.Keys | Should -Contain 'ManifestPath'
        $command.Parameters.Keys | Should -Contain 'PluginRoot'
        $command.Parameters.Keys | Should -Contain 'SchemaPath'
    }

    It 'uses approved parameter naming on the public release discovery command' {
        $command = Get-Command -Name Get-WintainiumApplicationRelease -Module Wintainium.Core
        $command.Parameters.Keys | Should -Contain 'ManifestPath'
        $command.Parameters.Keys | Should -Contain 'PluginRoot'
        $command.Parameters.Keys | Should -Contain 'SchemaPath'
    }

    It 'provides discoverable help for the public manifest command' {
        $help = Get-Help -Name Get-WintainiumManifest -Full
        $help.Synopsis | Should -Match 'Discovers and imports'
        $help.Examples.Example | Should -Not -BeNullOrEmpty
    }

    It 'provides discoverable help for the public application validation command' {
        $help = Get-Help -Name Test-WintainiumApplicationDefinition -Full
        $help.Synopsis | Should -Match 'Validates an offline'
        $help.Examples.Example | Should -Not -BeNullOrEmpty
    }

    It 'provides discoverable help for the public release discovery command' {
        $help = Get-Help -Name Get-WintainiumApplicationRelease -Full
        $help.Synopsis | Should -Match 'Validates an application manifest'
        $help.Examples.Example | Should -Not -BeNullOrEmpty
    }
}
