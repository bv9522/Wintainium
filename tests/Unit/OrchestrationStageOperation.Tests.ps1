Describe 'Invoke-WintainiumOrchestrationStageOperation' {
    BeforeAll {
        function New-TestStagePlan {
            param([Parameter(Mandatory)][string]$OperationId)
            [pscustomobject][ordered]@{
                OperationId = $OperationId
                Stages = @(
                    [pscustomobject]@{ Sequence = 1; Name = 'ManifestValidation' }
                    [pscustomobject]@{ Sequence = 2; Name = 'ReleaseDiscovery' }
                    [pscustomobject]@{ Sequence = 3; Name = 'UpdateDecision' }
                )
            }
        }

        function New-TestState {
            param([Parameter(Mandatory)][string]$OperationId)
            [pscustomobject][ordered]@{
                OperationId = $OperationId
                Status = 'Pending'
                CurrentStageSequence = 1
                CurrentStageName = 'ManifestValidation'
                CompletedStages = @()
                StageResults = @()
                FailedStage = $null
                Error = $null
            }
        }

        function New-TestContext {
            param(
                [Parameter(Mandatory)][string]$OperationId,
                [System.Threading.CancellationToken]$Token = [System.Threading.CancellationToken]::None
            )
            [pscustomobject][ordered]@{
                OperationId = $OperationId
                CancellationToken = $Token
                IsCancellationRequested = $Token.IsCancellationRequested
            }
        }
    }

    It 'executes the current stage and advances state through the transition boundary' {
        $operationId = [guid]::NewGuid().Guid
        $state = New-TestState -OperationId $operationId
        $plan = New-TestStagePlan -OperationId $operationId
        $context = New-TestContext -OperationId $operationId
        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
            param($OperationState, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationStageOperation -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput 'fixture-input' -StageExecutor {
                param($StageInput, $CancellationToken)
                [pscustomobject]@{ Accepted = $StageInput; Cancelled = $CancellationToken.IsCancellationRequested }
            }
        }

        $result.IsSuccessful | Should -BeTrue
        $result.Execution.IsSuccessful | Should -BeTrue
        $result.State.Status | Should -Be 'Running'
        $result.State.CurrentStageSequence | Should -Be 2
        $result.State.StageResults[0].Result.Accepted | Should -Be 'fixture-input'
    }

    It 'does not transition state when stage execution fails' {
        $operationId = [guid]::NewGuid().Guid
        $state = New-TestState -OperationId $operationId
        $plan = New-TestStagePlan -OperationId $operationId
        $context = New-TestContext -OperationId $operationId
        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
            param($OperationState, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationStageOperation -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput $null -StageExecutor { throw 'fixture failure' }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Execution.IsSuccessful | Should -BeFalse
        $result.Error.Code | Should -Be 'OrchestrationStageExecutionFailed'
        $result.State.Status | Should -Be 'Pending'
        $result.State.CompletedStages.Count | Should -Be 0
    }

    It 'does not transition state when execution is cancelled before start' {
        $operationId = [guid]::NewGuid().Guid
        $state = New-TestState -OperationId $operationId
        $plan = New-TestStagePlan -OperationId $operationId
        $cts = [System.Threading.CancellationTokenSource]::new()
        try {
            $cts.Cancel()
            $context = New-TestContext -OperationId $operationId -Token $cts.Token
            $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
                param($OperationState, $StagePlan, $CancellationContext)
                Invoke-WintainiumOrchestrationStageOperation -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput $null -StageExecutor { throw 'executor must not run' }
            }

            $result.IsSuccessful | Should -BeFalse
            $result.Execution.WasCancelled | Should -BeTrue
            $result.State.Status | Should -Be 'Pending'
        }
        finally { $cts.Dispose() }
    }

    It 'preserves the parent operation identifier' {
        $operationId = [guid]::NewGuid().Guid
        $state = New-TestState -OperationId $operationId
        $plan = New-TestStagePlan -OperationId $operationId
        $context = New-TestContext -OperationId $operationId
        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
            param($OperationState, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationStageOperation -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput 'x' -StageExecutor { param($StageInput, $CancellationToken) $StageInput }
        }

        $result.OperationId | Should -Be $operationId
        $result.Execution.OperationId | Should -Be $operationId
        $result.State.OperationId | Should -Be $operationId
    }

    It 'does not mutate the supplied operation state' {
        $operationId = [guid]::NewGuid().Guid
        $state = New-TestState -OperationId $operationId
        $plan = New-TestStagePlan -OperationId $operationId
        $context = New-TestContext -OperationId $operationId
        [void](InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
            param($OperationState, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationStageOperation -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput 'x' -StageExecutor { param($StageInput, $CancellationToken) $StageInput }
        })

        $state.Status | Should -Be 'Pending'
        $state.CurrentStageSequence | Should -Be 1
        $state.CompletedStages.Count | Should -Be 0
    }

    It 'rejects a state transition mismatch without invoking the executor' {
        $operationId = [guid]::NewGuid().Guid
        $state = New-TestState -OperationId $operationId
        $plan = New-TestStagePlan -OperationId $operationId
        $context = New-TestContext -OperationId $operationId
        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
            param($OperationState, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationStageOperation -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 2 -StageName 'ReleaseDiscovery' -StageInput $null -StageExecutor { throw 'executor must not run' }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Execution.Error.Code | Should -Be 'OrchestrationStageCurrentStageMismatch'
        $result.State.Status | Should -Be 'Pending'
    }

    It 'does not add a separate cancellation terminal state' {
        $operationId = [guid]::NewGuid().Guid
        $state = New-TestState -OperationId $operationId
        $plan = New-TestStagePlan -OperationId $operationId
        $cts = [System.Threading.CancellationTokenSource]::new()
        try {
            $cts.Cancel()
            $context = New-TestContext -OperationId $operationId -Token $cts.Token
            $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
                param($OperationState, $StagePlan, $CancellationContext)
                Invoke-WintainiumOrchestrationStageOperation -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput $null -StageExecutor { throw 'executor must not run' }
            }

            $result.State.Status | Should -Be 'Pending'
            $result.State.PSObject.Properties['Cancelled'] | Should -BeNullOrEmpty
        }
        finally { $cts.Dispose() }
    }
}
