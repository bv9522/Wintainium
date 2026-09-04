BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
    Import-Module $modulePath -Force

    $operationId = [guid]::NewGuid().ToString()

    function New-TestStagePlan {
        param(
            [string]$OperationId = $script:operationId
        )

        [pscustomobject][ordered]@{
            OperationId = $OperationId
            ManifestPath = 'C:\Manifests\example.json'
            MachineArchitecture = 'x64'
            DownloadRoot = 'C:\Downloads'
            Stages = @(
                [pscustomobject][ordered]@{ Sequence = 1; Name = 'ManifestValidation'; Required = $true }
                [pscustomobject][ordered]@{ Sequence = 2; Name = 'ReleaseDiscovery'; Required = $true }
                [pscustomobject][ordered]@{ Sequence = 3; Name = 'UpdateDecision'; Required = $true }
                [pscustomobject][ordered]@{ Sequence = 4; Name = 'Download'; Required = $true }
                [pscustomobject][ordered]@{ Sequence = 5; Name = 'Verification'; Required = $true }
                [pscustomobject][ordered]@{ Sequence = 6; Name = 'InstallerSelection'; Required = $true }
                [pscustomobject][ordered]@{ Sequence = 7; Name = 'Installation'; Required = $true }
            )
        }
    }
}

Describe 'New-WintainiumOrchestrationOperationState' {
    It 'initializes deterministic pending state from a valid stage plan' {
        $result = New-WintainiumOrchestrationOperationState -StagePlan (New-TestStagePlan)

        $result.IsValid | Should -BeTrue
        $result.State.Status | Should -Be 'Pending'
        $result.State.CurrentStageSequence | Should -Be 1
        $result.State.CurrentStageName | Should -Be 'ManifestValidation'
        $result.State.OperationId | Should -Be $operationId
        $result.Errors.Count | Should -Be 0
    }

    It 'preserves the parent operation identifier without creating a second identifier' {
        $plan = New-TestStagePlan
        $result = New-WintainiumOrchestrationOperationState -StagePlan $plan

        $result.State.OperationId | Should -Be $plan.OperationId
        $result.State.PSObject.Properties.Name | Should -Not -Contain 'ParentOperationId'
        $result.State.PSObject.Properties.Name | Should -Not -Contain 'NewOperationId'
    }

    It 'does not fabricate completed stages or stage results' {
        $result = New-WintainiumOrchestrationOperationState -StagePlan (New-TestStagePlan)

        $result.State.CompletedStages.Count | Should -Be 0
        $result.State.StageResults.Count | Should -Be 0
        $result.State.FailedStage | Should -BeNullOrEmpty
        $result.State.Error | Should -BeNullOrEmpty
    }

    It 'rejects a missing stage plan structurally' {
        $result = New-WintainiumOrchestrationOperationState -StagePlan $null

        $result.IsValid | Should -BeFalse
        $result.State | Should -BeNullOrEmpty
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStatePlanMissing'
    }

    It 'rejects a malformed operation identifier' {
        $result = New-WintainiumOrchestrationOperationState -StagePlan (New-TestStagePlan -OperationId 'not-a-guid')

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStateOperationIdInvalid'
    }

    It 'rejects an empty stage collection' {
        $plan = New-TestStagePlan
        $plan.Stages = @()

        $result = New-WintainiumOrchestrationOperationState -StagePlan $plan

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStateStagesMissing'
    }

    It 'rejects non-contiguous stage sequences' {
        $plan = New-TestStagePlan
        $plan.Stages[3].Sequence = 9

        $result = New-WintainiumOrchestrationOperationState -StagePlan $plan

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStateStageSequenceInvalid'
    }

    It 'does not require stage-owned resources to exist before initializing state' {
        $plan = New-TestStagePlan
        $plan.ManifestPath = 'C:\does-not-exist\manifest.json'
        $plan.DownloadRoot = 'C:\does-not-exist\downloads'

        $result = New-WintainiumOrchestrationOperationState -StagePlan $plan

        $result.IsValid | Should -BeTrue
        $result.State.Status | Should -Be 'Pending'
    }
}
