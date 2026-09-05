Describe 'Invoke-WintainiumOrchestrationWorkflow' {
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
            [pscustomobject][ordered]@{ OperationId = $OperationId; Status = 'Pending'; CurrentStageSequence = 1; CurrentStageName = 'ManifestValidation'; CompletedStages = @(); StageResults = @(); FailedStage = $null; Error = $null }
        }
        function New-TestContext {
            param([Parameter(Mandatory)][string]$OperationId, [System.Threading.CancellationToken]$Token = [System.Threading.CancellationToken]::None)
            [pscustomobject][ordered]@{ OperationId = $OperationId; CancellationToken = $Token; IsCancellationRequested = $Token.IsCancellationRequested }
        }
        InModuleScope Wintainium.Core {
            function New-TestBinding {
                param([object]$InputValue, [scriptblock]$Executor)
                [pscustomobject][ordered]@{ StageInput = $InputValue; StageExecutor = $Executor }
            }
        }
    }

    It 'executes every planned stage in authoritative order and completes the operation' {
        $operationId = [guid]::NewGuid().Guid; $state = New-TestState $operationId; $plan = New-TestStagePlan $operationId; $context = New-TestContext $operationId; $seen = [System.Collections.Generic.List[int]]::new()
        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context; Seen = $seen } {
            param($OperationState, $StagePlan, $CancellationContext, $Seen)
            Invoke-WintainiumOrchestrationWorkflow -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory {
                param($Stage, $CurrentState, $CurrentContext); $Seen.Add([int]$Stage.Sequence); New-TestBinding $Stage.Name { param($StageInput, $CancellationToken) [pscustomobject]@{ Stage = $StageInput } }
            }
        }
        $result.IsSuccessful | Should -BeTrue; $result.State.Status | Should -Be 'Completed'; $result.State.CurrentStageSequence | Should -BeNullOrEmpty; $result.State.CompletedStages.Count | Should -Be 3; @($seen) | Should -Be @(1,2,3)
    }

    It 'passes the evolving immutable state to the stage factory' {
        $operationId = [guid]::NewGuid().Guid; $state = New-TestState $operationId; $plan = New-TestStagePlan $operationId; $context = New-TestContext $operationId; $observed = [System.Collections.Generic.List[int]]::new()
        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context; Observed = $observed } {
            param($OperationState, $StagePlan, $CancellationContext, $Observed)
            Invoke-WintainiumOrchestrationWorkflow -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory {
                param($Stage, $CurrentState, $CurrentContext); $Observed.Add([int]$CurrentState.CurrentStageSequence); New-TestBinding $Stage.Sequence { param($StageInput, $CancellationToken) $StageInput }
            }
        }
        $result.IsSuccessful | Should -BeTrue; @($observed) | Should -Be @(1,2,3)
    }

    It 'fails fast and returns the failed state when a stage fails' {
        $operationId = [guid]::NewGuid().Guid; $state = New-TestState $operationId; $plan = New-TestStagePlan $operationId; $context = New-TestContext $operationId; $seen = [System.Collections.Generic.List[int]]::new()
        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context; Seen = $seen } {
            param($OperationState, $StagePlan, $CancellationContext, $Seen)
            Invoke-WintainiumOrchestrationWorkflow -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory {
                param($Stage, $CurrentState, $CurrentContext); $Seen.Add([int]$Stage.Sequence); if ($Stage.Sequence -eq 2) { New-TestBinding $Stage.Name { throw 'fixture failure' } } else { New-TestBinding $Stage.Name { param($StageInput, $CancellationToken) $StageInput } }
            }
        }
        $result.IsSuccessful | Should -BeFalse; $result.Error.Code | Should -Be 'OrchestrationStageExecutionFailed'; $result.State.Status | Should -Be 'Failed'; $result.State.FailedStage.Sequence | Should -Be 2; @($seen) | Should -Be @(1,2)
    }

    It 'does not invoke a later stage after failure' {
        $operationId = [guid]::NewGuid().Guid; $state = New-TestState $operationId; $plan = New-TestStagePlan $operationId; $context = New-TestContext $operationId; $calls = [System.Collections.Generic.List[int]]::new()
        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context; Calls = $calls } {
            param($OperationState, $StagePlan, $CancellationContext, $Calls)
            Invoke-WintainiumOrchestrationWorkflow -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory {
                param($Stage, $CurrentState, $CurrentContext); New-TestBinding $Stage.Sequence { param($StageInput, $CancellationToken) $Calls.Add([int]$StageInput); if ([int]$StageInput -eq 2) { throw 'fixture failure' }; $StageInput }
            }
        }
        $result.IsSuccessful | Should -BeFalse; @($calls) | Should -Be @(1,2)
    }

    It 'stops before the next stage when cancellation is requested between stages' {
        $operationId = [guid]::NewGuid().Guid; $state = New-TestState $operationId; $plan = New-TestStagePlan $operationId; $cts = [System.Threading.CancellationTokenSource]::new()
        try {
            $context = New-TestContext $operationId $cts.Token; $seen = [System.Collections.Generic.List[int]]::new()
            $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context; Seen = $seen; Cts = $cts } {
                param($OperationState, $StagePlan, $CancellationContext, $Seen, $Cts)
                Invoke-WintainiumOrchestrationWorkflow -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory {
                    param($Stage, $CurrentState, $CurrentContext)
                    $Seen.Add([int]$Stage.Sequence)
                    if ($Stage.Sequence -eq 1) {
                        New-TestBinding $Stage.Name { param($StageInput, $CancellationToken) $Cts.Cancel(); $StageInput }
                    }
                    else {
                        New-TestBinding $Stage.Name { param($StageInput, $CancellationToken) $StageInput }
                    }
                }
            }
            $result.IsSuccessful | Should -BeFalse; $result.WasCancelled | Should -BeTrue; $result.State.Status | Should -Be 'Running'; @($seen) | Should -Be @(1); $result.State.CompletedStages.Count | Should -Be 1
        } finally { $cts.Dispose() }
    }

    It 'does not add a cancellation terminal status' {
        $operationId = [guid]::NewGuid().Guid; $state = New-TestState $operationId; $plan = New-TestStagePlan $operationId; $cts = [System.Threading.CancellationTokenSource]::new()
        try {
            $cts.Cancel(); $context = New-TestContext $operationId $cts.Token
            $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
                param($OperationState, $StagePlan, $CancellationContext)
                Invoke-WintainiumOrchestrationWorkflow -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory { throw 'factory must not run' }
            }
            $result.WasCancelled | Should -BeTrue; $result.State.Status | Should -Be 'Pending'; $result.State.PSObject.Properties['Cancelled'] | Should -BeNullOrEmpty
        } finally { $cts.Dispose() }
    }

    It 'preserves the parent operation identifier across the workflow' {
        $operationId = [guid]::NewGuid().Guid; $state = New-TestState $operationId; $plan = New-TestStagePlan $operationId; $context = New-TestContext $operationId
        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
            param($OperationState, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationWorkflow -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory { param($Stage, $CurrentState, $CurrentContext) New-TestBinding $Stage.Name { param($StageInput, $CancellationToken) $StageInput } }
        }
        $result.OperationId | Should -Be $operationId; $result.State.OperationId | Should -Be $operationId; $result.StageResults[0].OperationId | Should -Be $operationId; $result.StageResults[2].OperationId | Should -Be $operationId
    }

    It 'does not mutate the supplied operation state' {
        $operationId = [guid]::NewGuid().Guid; $state = New-TestState $operationId; $plan = New-TestStagePlan $operationId; $context = New-TestContext $operationId
        [void](InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
            param($OperationState, $StagePlan, $CancellationContext); Invoke-WintainiumOrchestrationWorkflow -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory { param($Stage, $CurrentState, $CurrentContext) New-TestBinding $Stage.Name { param($StageInput, $CancellationToken) $StageInput } }
        })
        $state.Status | Should -Be 'Pending'; $state.CurrentStageSequence | Should -Be 1; $state.CompletedStages.Count | Should -Be 0
    }

    It 'rejects an empty stage plan without invoking the factory' {
        $operationId = [guid]::NewGuid().Guid; $state = New-TestState $operationId; $plan = [pscustomobject]@{ OperationId = $operationId; Stages = @() }; $context = New-TestContext $operationId
        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } { param($OperationState, $StagePlan, $CancellationContext) Invoke-WintainiumOrchestrationWorkflow -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory { throw 'factory must not run' } }
        $result.IsSuccessful | Should -BeFalse; $result.Error.Code | Should -Be 'OrchestrationWorkflowStagePlanEmpty'; $result.State | Should -Be $state
    }

    It 'returns a structured failure when the stage factory fails' {
        $operationId = [guid]::NewGuid().Guid; $state = New-TestState $operationId; $plan = New-TestStagePlan $operationId; $context = New-TestContext $operationId
        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } { param($OperationState, $StagePlan, $CancellationContext) Invoke-WintainiumOrchestrationWorkflow -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory { throw 'factory failure' } }
        $result.IsSuccessful | Should -BeFalse; $result.Error.Code | Should -Be 'OrchestrationWorkflowStageFactoryFailed'; $result.State.Status | Should -Be 'Pending'; $result.StageResults.Count | Should -Be 0
    }
}
