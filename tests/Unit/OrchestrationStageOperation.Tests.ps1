Describe 'Invoke-WintainiumOrchestrationStageOperation' {
    BeforeAll {
        $operationId = [guid]::NewGuid().Guid

        function New-TestStagePlan {
            param([string]$OperationId)
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
            $result = New-WintainiumOrchestrationOperationState -StagePlan (New-TestStagePlan -OperationId $operationId)
            if (-not $result.IsValid) { throw 'Test state could not be created.' }
            $result.State
        }

        function New-TestContext {
            param([System.Threading.CancellationToken]$Token = [System.Threading.CancellationToken]::None)
            [pscustomobject][ordered]@{
                OperationId = $operationId
                CancellationToken = $Token
                IsCancellationRequested = $Token.IsCancellationRequested
            }
        }
    }

    It 'executes the current stage and advances state through the transition boundary' {
        InModuleScope Wintainium.Core {
            $state = New-TestState
            $plan = New-TestStagePlan -OperationId $operationId
            $context = New-TestContext
            $result = Invoke-WintainiumOrchestrationStageOperation -OperationState $state -StagePlan $plan -CancellationContext $context -StageSequence 1 -StageName 'ManifestValidation' -StageInput 'fixture-input' -StageExecutor {
                param($StageInput, $CancellationToken)
                [pscustomobject]@{ Accepted = $StageInput; Cancelled = $CancellationToken.IsCancellationRequested }
            }

            $result.IsSuccessful | Should -BeTrue
            $result.Execution.IsSuccessful | Should -BeTrue
            $result.State.Status | Should -Be 'Running'
            $result.State.CurrentStageSequence | Should -Be 2
            $result.State.StageResults[0].Result.Accepted | Should -Be 'fixture-input'
        }
    }

    It 'does not transition state when stage execution fails' {
        InModuleScope Wintainium.Core {
            $state = New-TestState
            $plan = New-TestStagePlan -OperationId $operationId
            $context = New-TestContext
            $result = Invoke-WintainiumOrchestrationStageOperation -OperationState $state -StagePlan $plan -CancellationContext $context -StageSequence 1 -StageName 'ManifestValidation' -StageInput $null -StageExecutor {
                throw 'fixture failure'
            }

            $result.IsSuccessful | Should -BeFalse
            $result.Execution.IsSuccessful | Should -BeFalse
            $result.Error.Code | Should -Be 'OrchestrationStageExecutionFailed'
            $result.State.Status | Should -Be 'Pending'
            $result.State.CompletedStages.Count | Should -Be 0
        }
    }

    It 'does not transition state when execution is cancelled before start' {
        InModuleScope Wintainium.Core {
            $state = New-TestState
            $plan = New-TestStagePlan -OperationId $operationId
            $cts = [System.Threading.CancellationTokenSource]::new()
            $cts.Cancel()
            $context = New-TestContext -Token $cts.Token
            $executed = $false
            $result = Invoke-WintainiumOrchestrationStageOperation -OperationState $state -StagePlan $plan -CancellationContext $context -StageSequence 1 -StageName 'ManifestValidation' -StageInput $null -StageExecutor {
                $executed = $true
            }

            $result.IsSuccessful | Should -BeFalse
            $result.Execution.WasCancelled | Should -BeTrue
            $executed | Should -BeFalse
            $result.State.Status | Should -Be 'Pending'
        }
    }

    It 'preserves the parent operation identifier' {
        InModuleScope Wintainium.Core {
            $state = New-TestState
            $plan = New-TestStagePlan -OperationId $operationId
            $context = New-TestContext
            $result = Invoke-WintainiumOrchestrationStageOperation -OperationState $state -StagePlan $plan -CancellationContext $context -StageSequence 1 -StageName 'ManifestValidation' -StageInput 'x' -StageExecutor { param($StageInput, $CancellationToken) $StageInput }

            $result.OperationId | Should -Be $operationId
            $result.Execution.OperationId | Should -Be $operationId
            $result.State.OperationId | Should -Be $operationId
        }
    }

    It 'does not mutate the supplied operation state' {
        InModuleScope Wintainium.Core {
            $state = New-TestState
            $plan = New-TestStagePlan -OperationId $operationId
            $context = New-TestContext
            [void](Invoke-WintainiumOrchestrationStageOperation -OperationState $state -StagePlan $plan -CancellationContext $context -StageSequence 1 -StageName 'ManifestValidation' -StageInput 'x' -StageExecutor { param($StageInput, $CancellationToken) $StageInput })

            $state.Status | Should -Be 'Pending'
            $state.CurrentStageSequence | Should -Be 1
            $state.CompletedStages.Count | Should -Be 0
        }
    }

    It 'rejects a state transition mismatch without invoking the executor' {
        InModuleScope Wintainium.Core {
            $state = New-TestState
            $plan = New-TestStagePlan -OperationId $operationId
            $context = New-TestContext
            $executed = $false
            $result = Invoke-WintainiumOrchestrationStageOperation -OperationState $state -StagePlan $plan -CancellationContext $context -StageSequence 2 -StageName 'ReleaseDiscovery' -StageInput $null -StageExecutor { $executed = $true }

            $result.IsSuccessful | Should -BeFalse
            $executed | Should -BeFalse
            $result.Execution.Error.Code | Should -Be 'OrchestrationStageCurrentStageMismatch'
            $result.State.Status | Should -Be 'Pending'
        }
    }

    It 'does not add a separate cancellation terminal state' {
        InModuleScope Wintainium.Core {
            $state = New-TestState
            $plan = New-TestStagePlan -OperationId $operationId
            $cts = [System.Threading.CancellationTokenSource]::new()
            $cts.Cancel()
            $context = New-TestContext -Token $cts.Token
            $result = Invoke-WintainiumOrchestrationStageOperation -OperationState $state -StagePlan $plan -CancellationContext $context -StageSequence 1 -StageName 'ManifestValidation' -StageInput $null -StageExecutor { }

            $result.State.Status | Should -Be 'Pending'
            $result.State.PSObject.Properties['Cancelled'] | Should -BeNullOrEmpty
        }
    }
}
