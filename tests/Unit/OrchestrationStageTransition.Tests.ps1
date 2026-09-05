BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
    Import-Module $modulePath -Force

    $operationId = [guid]::NewGuid().ToString()

    function New-TestStagePlan {
        param(
            [Parameter(Mandatory)]
            [string]$OperationId
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

    function New-TestState {
        $plan = New-TestStagePlan -OperationId $operationId
        $result = InModuleScope Wintainium.Core -Parameters @{ StagePlan = $plan } {
            param($StagePlan)
            New-WintainiumOrchestrationOperationState -StagePlan $StagePlan
        }
        if (-not $result.IsValid) {
            throw "Test fixture operation state construction failed: $($result.Errors | ConvertTo-Json -Compress)"
        }
        $result.State
    }
}

Describe 'Update-WintainiumOrchestrationOperationState' {
    It 'advances a successful stage to the next planned stage' {
        $state = New-TestState
        $plan = New-TestStagePlan -OperationId $operationId
        $stageResult = [pscustomobject]@{ Status = 'Succeeded' }

        $result = InModuleScope Wintainium.Core -Parameters @{
            State = $state
            StagePlan = $plan
            StageResult = $stageResult
        } {
            param($State, $StagePlan, $StageResult)
            Update-WintainiumOrchestrationOperationState -State $State -StagePlan $StagePlan -StageSequence 1 -StageName 'ManifestValidation' -StageResult $StageResult -Succeeded $true
        }

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
        $plan = New-TestStagePlan -OperationId $operationId

        $result = InModuleScope Wintainium.Core -Parameters @{ State = $state; StagePlan = $plan } {
            param($State, $StagePlan)
            Update-WintainiumOrchestrationOperationState -State $State -StagePlan $StagePlan -StageSequence 1 -StageName 'ManifestValidation' -StageResult ([pscustomobject]@{}) -Succeeded $true
        }

        $result.State.OperationId | Should -Be $operationId
    }

    It 'records a failed stage without advancing to the next stage' {
        $state = New-TestState
        $plan = New-TestStagePlan -OperationId $operationId
        $stageResult = [pscustomobject]@{ Status = 'Failed'; FailureKind = 'Network' }

        $result = InModuleScope Wintainium.Core -Parameters @{
            State = $state
            StagePlan = $plan
            StageResult = $stageResult
        } {
            param($State, $StagePlan, $StageResult)
            Update-WintainiumOrchestrationOperationState -State $State -StagePlan $StagePlan -StageSequence 1 -StageName 'ManifestValidation' -StageResult $StageResult -Succeeded $false
        }

        $result.IsValid | Should -BeTrue
        $result.State.Status | Should -Be 'Failed'
        $result.State.CurrentStageSequence | Should -Be 1
        $result.State.CurrentStageName | Should -Be 'ManifestValidation'
        $result.State.FailedStage.Name | Should -Be 'ManifestValidation'
        $result.State.Error | Should -Be $stageResult
    }

    It 'completes the operation when the final planned stage succeeds' {
        $state = New-TestState
        $plan = New-TestStagePlan -OperationId $operationId
        $state.CurrentStageSequence = 7
        $state.CurrentStageName = 'Installation'
        $stageResult = [pscustomobject]@{ Status = 'Succeeded' }

        $result = InModuleScope Wintainium.Core -Parameters @{
            State = $state
            StagePlan = $plan
            StageResult = $stageResult
        } {
            param($State, $StagePlan, $StageResult)
            Update-WintainiumOrchestrationOperationState -State $State -StagePlan $StagePlan -StageSequence 7 -StageName 'Installation' -StageResult $StageResult -Succeeded $true
        }

        $result.IsValid | Should -BeTrue
        $result.State.Status | Should -Be 'Completed'
        $result.State.CurrentStageSequence | Should -BeNullOrEmpty
        $result.State.CurrentStageName | Should -BeNullOrEmpty
        $result.State.CompletedStages.Count | Should -Be 1
    }

    It 'does not mutate the supplied state when a transition succeeds' {
        $state = New-TestState
        $plan = New-TestStagePlan -OperationId $operationId
        $originalStatus = $state.Status
        $originalSequence = $state.CurrentStageSequence
        $originalName = $state.CurrentStageName
        $originalCompletedCount = $state.CompletedStages.Count
        $originalResultCount = $state.StageResults.Count

        $result = InModuleScope Wintainium.Core -Parameters @{ State = $state; StagePlan = $plan } {
            param($State, $StagePlan)
            Update-WintainiumOrchestrationOperationState -State $State -StagePlan $StagePlan -StageSequence 1 -StageName 'ManifestValidation' -StageResult ([pscustomobject]@{}) -Succeeded $true
        }

        $result.IsValid | Should -BeTrue
        $state.Status | Should -Be $originalStatus
        $state.CurrentStageSequence | Should -Be $originalSequence
        $state.CurrentStageName | Should -Be $originalName
        $state.CompletedStages.Count | Should -Be $originalCompletedCount
        $state.StageResults.Count | Should -Be $originalResultCount
        $state.FailedStage | Should -BeNullOrEmpty
        $state.Error | Should -BeNullOrEmpty
    }

    It 'rejects a stage result for a non-current stage' {
        $state = New-TestState
        $plan = New-TestStagePlan -OperationId $operationId

        $result = InModuleScope Wintainium.Core -Parameters @{ State = $state; StagePlan = $plan } {
            param($State, $StagePlan)
            Update-WintainiumOrchestrationOperationState -State $State -StagePlan $StagePlan -StageSequence 2 -StageName 'ReleaseDiscovery' -StageResult ([pscustomobject]@{}) -Succeeded $true
        }

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStateStageMismatch'
    }

    It 'rejects a stage name that does not match the current stage' {
        $state = New-TestState
        $plan = New-TestStagePlan -OperationId $operationId

        $result = InModuleScope Wintainium.Core -Parameters @{ State = $state; StagePlan = $plan } {
            param($State, $StagePlan)
            Update-WintainiumOrchestrationOperationState -State $State -StagePlan $StagePlan -StageSequence 1 -StageName 'ReleaseDiscovery' -StageResult ([pscustomobject]@{}) -Succeeded $true
        }

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStateStageMismatch'
    }

    It 'rejects an operation identifier mismatch between state and plan' {
        $state = New-TestState
        $plan = New-TestStagePlan -OperationId ([guid]::NewGuid().ToString())

        $result = InModuleScope Wintainium.Core -Parameters @{ State = $state; StagePlan = $plan } {
            param($State, $StagePlan)
            Update-WintainiumOrchestrationOperationState -State $State -StagePlan $StagePlan -StageSequence 1 -StageName 'ManifestValidation' -StageResult ([pscustomobject]@{}) -Succeeded $true
        }

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStateOperationIdMismatch'
    }

    It 'rejects transitions from a terminal state' {
        $state = New-TestState
        $state.Status = 'Failed'
        $plan = New-TestStagePlan -OperationId $operationId

        $result = InModuleScope Wintainium.Core -Parameters @{ State = $state; StagePlan = $plan } {
            param($State, $StagePlan)
            Update-WintainiumOrchestrationOperationState -State $State -StagePlan $StagePlan -StageSequence 1 -StageName 'ManifestValidation' -StageResult ([pscustomobject]@{}) -Succeeded $true
        }

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationOperationStateTerminal'
    }

    It 'preserves a null stage result when the stage itself failed' {
        $state = New-TestState
        $plan = New-TestStagePlan -OperationId $operationId

        $result = InModuleScope Wintainium.Core -Parameters @{ State = $state; StagePlan = $plan } {
            param($State, $StagePlan)
            Update-WintainiumOrchestrationOperationState -State $State -StagePlan $StagePlan -StageSequence 1 -StageName 'ManifestValidation' -StageResult $null -Succeeded $false
        }

        $result.IsValid | Should -BeTrue
        $result.State.Status | Should -Be 'Failed'
        $result.State.StageResults[0].Result | Should -BeNullOrEmpty
        $result.State.Error | Should -BeNullOrEmpty
    }
}