Describe 'Wintainium public application update execution boundary' {
    BeforeAll {
        $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
        Import-Module $script:modulePath -Force
    }

    AfterAll {
        Remove-Module -Name Wintainium.Core -Force -ErrorAction SilentlyContinue
    }

    It 'returns a structured public failure when the lifecycle rejects the state root before orchestration starts' {
        $result = Invoke-WintainiumApplicationUpdate -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json' -StateRoot '   ' -MachineArchitecture 'x64' -DownloadRoot 'C:\Wintainium\Downloads'

        $result.Status | Should -Be 'Failed'
        $result.IsSuccessful | Should -BeFalse
        $result.WasCancelled | Should -BeFalse
        $result.OperationId | Should -Not -BeNullOrEmpty
        $result.Error.Code | Should -Be 'ApplicationUpdateStateRootInvalid'
        $result.Errors.Count | Should -Be 1
        $result.Errors[0].Code | Should -Be 'ApplicationUpdateStateRootInvalid'
        @($result.Stages).Count | Should -Be 0
    }
}