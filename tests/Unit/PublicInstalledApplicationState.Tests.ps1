$testRoot = Split-Path -Path (Split-Path -Parent $PSScriptRoot) -Parent
$modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

Import-Module $modulePath -Force

Describe 'Wintainium public installed application state command' {
    BeforeEach {
        $stateRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'returns a successful Unknown observation when no state exists' {
        $result = Get-WintainiumInstalledApplicationState -StateRoot $stateRoot -ApplicationId 'org.example.app'

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Unknown'
        $result.ApplicationId | Should -Be 'org.example.app'
        $result.State.InstallationState | Should -Be 'Unknown'
        @($result.Errors).Count | Should -Be 0
    }

    It 'returns the persisted authoritative state without changing its observations' {
        $state = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Installed -Version '1.2.vendor-build' -VersionSource Registry -Architecture x64 -Channel stable -InstallationLocation 'C:Program FilesExample'
        }

        InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot; State = $state } {
            param($StateRoot, $State)
            Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $State | Out-Null
        }

        $result = Get-WintainiumInstalledApplicationState -StateRoot $stateRoot -ApplicationId 'org.example.app'

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Installed'
        $result.State.ApplicationId | Should -Be 'org.example.app'
        $result.State.Version | Should -Be '1.2.vendor-build'
        $result.State.VersionSource | Should -Be 'Registry'
        $result.State.Architecture | Should -Be 'x64'
        $result.State.Channel | Should -Be 'stable'
        $result.State.InstallationLocation | Should -Be 'C:Program FilesExample'
    }

    It 'preserves Unknown instead of manufacturing installation state' {
        $state = InModuleScope Wintainium.Core {
            New-WintainiumInstalledApplicationState -ApplicationId 'org.example.app' -InstallationState Unknown
        }

        InModuleScope Wintainium.Core -Parameters @{ StateRoot = $stateRoot; State = $state } {
            param($StateRoot, $State)
            Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $State | Out-Null
        }

        $result = Get-WintainiumInstalledApplicationState -StateRoot $stateRoot -ApplicationId 'org.example.app'

        $result.IsSuccessful | Should -BeTrue
        $result.State.InstallationState | Should -Be 'Unknown'
        $result.State.Version | Should -BeNullOrEmpty
    }

    It 'returns a structured failure for malformed persisted state' {
        New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
        '{ invalid json' | Set-Content -LiteralPath (Join-Path $stateRoot 'installed-state.json')

        $result = Get-WintainiumInstalledApplicationState -StateRoot $stateRoot -ApplicationId 'org.example.app'

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'InstalledStateUnavailable'
        $result.State | Should -BeNullOrEmpty
        @($result.Errors | Where-Object Code -eq 'InstalledStateReadFailed').Count | Should -Be 1
    }

    It 'rejects an invalid operation identifier with a structured result' {
        $result = Get-WintainiumInstalledApplicationState -StateRoot $stateRoot -ApplicationId 'org.example.app' -OperationId 'not-a-guid'

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'InvalidInput'
        @($result.Errors | Where-Object Code -eq 'OperationIdInvalid').Count | Should -Be 1
    }
}
