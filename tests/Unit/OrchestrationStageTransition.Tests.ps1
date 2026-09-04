BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
    Import-Module $modulePath -Force

    $operationId = [guid]::NewGuid().ToString()

    function New-TestStagePlan {
        [pscustomobject][ordered]@{
            OperationId = $script:operationId
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

    function New-TestState {
        $result = New-WintainiumOrchestrationOperationState -StagePlan (New-TestStagePlan)
        $result.State
    }
}

Describe 'Update-WintainiumOrchestrationOperationState' {
    It 'advances a successful stage to the next planned stage' {
        $state = New-TestState
        $plan = New-TestStagePlan
        $stageResult = [pscustomobject]@{ Status = 'Succeeded' }

        $result = Update-WintainiumOrchestrationOperationState -State $state -StagePlan $plan -StageSequence 1 -StageName 'ManifestValidation' -StageResult $stageResult -Succeeded $true

        $result.IsValid | Should -BeTrue
        $result.State.Status | Should -Be 'Running'
        $result.State.CurrentStageSequence | Should -Be 2
        $result.State.CurrentStageName | Should -Be 'ReleaseDiscovery'
        $result.State.CompletedStages.Count | Should -Be 1
        $result.State.StageResults.Count | Should -Be 1
        $result.State.StageResults[0].Result | Should -Be $stageResult
    }

    It 'preserves the operation identifier across transitions' {
        $state = New-TestState
        $plan = New-TestStagePlan

        $result = Update-WintainiumOrchestrationOperationState -State $state -StagePlan $plan -StageSequence 1 -StageName 'ManifestValidation' -StageResult ([pscustomobject]@{}) -Succeeded $true

        $result.State.OperationId | Should -Be $operationId
    }

    It 'records a failed stage without advancing to the next stage' {
        $state = New-TestState
        $plan = New-TestStagePlan
        $stageResult = [pscustomobject]@{ Status = 'Failed'; FailureKind = 'Network' }

        $result = Update-WintainiumOrchestrationOperationState -State $state -StagePlan $plan -StageSequence 1 -StageName 'ManifestValidation' -StageResult $stageResult -Succeeded $false

        $result.IsValid | Should -BeTrue
        $result.State.Status | Should -Be 'Failed'
        $result.State.CurrentStageSequence | Should -Be 1
        $result.State.CurrentStageName | Should -Be 'ManifestValidation'
        $result.State.FailedStage.Name | Should -Be 'ManifestValidation'
        $result.State.Error | Should -Be $stageResult
    }

    It 'completes the operation when the final planned stage succeeds' {
        $state = New-TestState
        $plan = New-TestStagePlan
        $state.CurrentStageSequence = 7
        $state.CurrentStageName = 'Installation'
        $stageResult = [pscustomobject]@{ Status = 'Succeeded' }

        $result = Update-WintainiumOrchestrationOperationState -State $state -StagePlan $plan -StageSequence 7 -StageName 'Installation' -StageResult $stageResult -Succeeded $true

        $result.IsValid | Should -BeTrue
        $result.State.Status | Should -Be 'Completed'
        $result.State.CurrentStageSequence | Should -BeNullOrEmpty
        $result.State.CurrentStageName | Should -BeNullOrEmpty
        $result.State.CompletedStages.Count | Should -Be 1
    }

    It 'rejects a stage result for a non-current stage' {
        $state = New-TestState
        $plan = New-TestStagePlan

        $result = Update-WintainiumOrchestrationOperationState -State $state -StagePlan $plan -StageSequence 2 -StageName 'ReleaseDiscovery' -StageResult ([pscustomobject]@{}) -Succeeded $true

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStateStageMismatch'
    }

    It 'rejects a stage name that does not match the current stage' {
        $state = New-TestState
        $plan = New-TestStagePlan

        $result = Update-WintainiumOrchestrationOperationState -State $state -StagePlan $plan -StageSequence 1 -StageName 'ReleaseDiscovery' -StageResult ([pscustomobject]@{}) -Succeeded $true

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStateStageMismatch'
    }

    It 'rejects an operation identifier mismatch between state and plan' {
        $state = New-TestState
        $plan = New-TestStagePlan
        $plan.OperationId = [guid]::NewGuid().ToString()

        $result = Update-WintainiumOrchestrationOperationState -State $state -StagePlan $plan -StageSequence 1 -StageName 'ManifestValidation' -StageResult ([pscustomobject]@{}) -Succeeded $true

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStateOperationIdMismatch'
    }

    It 'rejects transitions from a terminal state' {
        $state = New-TestState
        $state.Status = 'Failed'
        $plan = New-TestStagePlan

        $result = Update-WintainiumOrchestrationOperationState -State $state -StagePlan $plan -StageSequence 1 -StageName 'ManifestValidation' -StageResult ([pscustomobject]@{}) -Succeeded $true

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStateTerminal'
    }

    It 'preserves a null stage result when the stage itself failed' {
        $state = New-TestState
        $plan = New-TestStagePlan

        $result = Update-WintainiumOrchestrationOperationState -State $state -StagePlan $plan -StageSequence 1 -StageName 'ManifestValidation' -StageResult $null -Succeeded $false

        $result.IsValid | Should -BeTrue
        $result.State.Status | Should -Be 'Failed'
        $result.State.StageResults[0].Result | Should -BeNullOrEmpty
        $result.State.Error | Should -BeNullOrEmpty
    }
}