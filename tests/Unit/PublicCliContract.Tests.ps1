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
            'Invoke-WintainiumApplicationUpdate'
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

    It 'uses the approved parameter contract on the public application update command' {
        $command = Get-Command -Name Invoke-WintainiumApplicationUpdate -Module Wintainium.Core

        $command.Parameters.Keys | Should -Contain 'ManifestPath'
        $command.Parameters.Keys | Should -Contain 'StateRoot'
        $command.Parameters.Keys | Should -Contain 'MachineArchitecture'
        $command.Parameters.Keys | Should -Contain 'DownloadRoot'
        $command.Parameters.Keys | Should -Contain 'PluginRoot'
        $command.Parameters.Keys | Should -Contain 'SchemaPath'
        $command.Parameters.Keys | Should -Contain 'InstallerTimeoutMilliseconds'
        $command.Parameters.Keys | Should -Contain 'CancellationToken'

        $command.Parameters.Keys | Should -Not -Contain 'OperationId'
        $command.Parameters.Keys | Should -Not -Contain 'HttpClient'
        $command.Parameters.Keys | Should -Not -Contain 'WhatIf'
    }

    It 'provides discoverable help for the public application update command' {
        $help = Get-Help -Name Invoke-WintainiumApplicationUpdate -Full

        $help.Synopsis | Should -Match 'complete application update lifecycle'
        $help.Examples.Example | Should -Not -BeNullOrEmpty

        $helpText = $help | Out-String
        foreach ($parameter in @('ManifestPath', 'StateRoot', 'MachineArchitecture', 'DownloadRoot', 'PluginRoot', 'SchemaPath', 'InstallerTimeoutMilliseconds', 'CancellationToken')) {
            $helpText | Should -Match $parameter
        }

        $helpText | Should -Match 'does not supply an OperationId'
        $helpText | Should -Match 'performs update execution'
    }

    It 'documents the public application update structured output contract' {
        $helpText = Get-Help -Name Invoke-WintainiumApplicationUpdate -Full | Out-String

        foreach ($property in @('OperationId', 'IsSuccessful', 'WasCancelled', 'Status', 'ApplicationId', 'Stages', 'Errors', 'Warnings', 'LogEvents', 'Error')) {
            $helpText | Should -Match $property
        }

        $helpText | Should -Match 'stable, presentation-neutral public result projection'
        $helpText | Should -Match 'Internal orchestration state and stage-operation objects are not exposed'
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

    It 'documents the complete structured output contract for the public manifest command' {
        $helpText = Get-Help -Name Get-WintainiumManifest -Full | Out-String
        foreach ($property in @('OperationId', 'IsSuccessful', 'Candidates', 'ManifestPaths', 'Manifests', 'Errors', 'Warnings', 'LogEvents')) {
            $helpText | Should -Match $property
        }
    }

    It 'documents the complete structured output contract for the public application validation command' {
        $helpText = Get-Help -Name Test-WintainiumApplicationDefinition -Full | Out-String
        foreach ($property in @('OperationId', 'IsValid', 'Manifest', 'ProviderPlugin', 'InstallerPlugin', 'ReconciliationPlugin', 'Errors', 'Warnings', 'LogEvents')) {
            $helpText | Should -Match $property
        }
    }

    It 'documents the complete structured output contract for the public release discovery command' {
        $helpText = Get-Help -Name Get-WintainiumApplicationRelease -Full | Out-String
        foreach ($property in @('OperationId', 'IsSuccessful', 'Status', 'Manifest', 'ProviderPlugin', 'Releases', 'Errors', 'Warnings', 'LogEvents')) {
            $helpText | Should -Match $property
        }
    }

    It 'documents that manifest discovery is offline and import-only' {
        $helpText = Get-Help -Name Get-WintainiumManifest -Full | Out-String
        $helpText | Should -Match 'offline manifest discovery and import only'
    }

    It 'documents that application validation does not perform execution work' {
        $helpText = Get-Help -Name Test-WintainiumApplicationDefinition -Full | Out-String
        $helpText | Should -Match 'no network,\s*download,\s*installation, or installed-state management work'
    }

    It 'documents that release discovery does not perform update execution' {
        $helpText = Get-Help -Name Get-WintainiumApplicationRelease -Full | Out-String
        $helpText | Should -Match 'does not decide'
        $helpText | Should -Match 'download\s+an\s+artifact'
        $helpText | Should -Match 'install\s+anything'
    }
}
