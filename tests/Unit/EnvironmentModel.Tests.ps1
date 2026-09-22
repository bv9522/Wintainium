$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium environment model' {
    It 'returns the current Windows environment with normalized architecture facts' {
        $result = InModuleScope Wintainium.Core { Get-WintainiumEnvironment }

        $result.OperatingSystem | Should -Be 'Windows'
        $result.OperatingSystemVersion | Should -Not -BeNullOrEmpty
        $result.OperatingSystemBuild | Should -BeGreaterThan 0
        $result.MachineArchitecture | Should -BeIn @('x64','x86','arm64','arm','unknown')
        $result.ProcessArchitecture | Should -BeIn @('x64','x86','arm64','arm','unknown')
    }

    It 'allows deterministic environment overrides for tests and future orchestration inputs' {
        $overrides = [pscustomobject]@{
            OperatingSystem = 'Windows'
            OperatingSystemVersion = '10.0.26100.1'
            OperatingSystemBuild = 26100
            MachineArchitecture = 'x64'
            ProcessArchitecture = 'x64'
        }

        $result = InModuleScope Wintainium.Core -Parameters @{Overrides=$overrides} {
            param($Overrides)
            Get-WintainiumEnvironment -Overrides $Overrides
        }

        $result.OperatingSystem | Should -Be 'Windows'
        $result.OperatingSystemVersion | Should -Be '10.0.26100.1'
        $result.OperatingSystemBuild | Should -Be 26100
        $result.MachineArchitecture | Should -Be 'x64'
        $result.ProcessArchitecture | Should -Be 'x64'
    }

    It 'uses OS architecture for machine architecture rather than process architecture' {
        $overrides = [pscustomobject]@{
            MachineArchitecture = 'x64'
            ProcessArchitecture = 'x86'
        }

        $result = InModuleScope Wintainium.Core -Parameters @{Overrides=$overrides} {
            param($Overrides)
            Get-WintainiumEnvironment -Overrides $Overrides
        }

        $result.MachineArchitecture | Should -Be 'x64'
        $result.ProcessArchitecture | Should -Be 'x86'
    }

    It 'does not invent application installation state' {
        $result = InModuleScope Wintainium.Core { Get-WintainiumEnvironment }

        $result.PSObject.Properties.Name | Should -Not -Contain 'InstalledApplications'
        $result.PSObject.Properties.Name | Should -Not -Contain 'ApplicationState'
    }
}
