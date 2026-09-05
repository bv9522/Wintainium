BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
    Import-Module $modulePath -Force

    $operationId = [guid]::NewGuid().ToString()

    function New-TestStagePlan {
        param([Parameter(Mandatory)][string]$OperationId)

        [pscustomobject][ordered]@{
            OperationId = $OperationId
            Stages = @(
                [pscustomobject]@{ Sequence = 1; Name = 'ManifestValidation' }
                [pscustomobject]@{ Sequence = 2; Name = 'ReleaseDiscovery' }
            )
        }
    }

    function New-TestOperationState {
        [pscustomobject][ordered]@{
            OperationId = $operationId
            Status = 'Running'
            CurrentStageSequence = 1
            CurrentStageName = 'ManifestValidation'
            CompletedStages = @()
            StageResults = @()
            FailedStage = $null
            Error = $null
        }
    }

    function New-TestCancellationContext {
        param([System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None)

        [pscustomobject][ordered]@{
            OperationId = $operationId
            CancellationToken = $CancellationToken
            IsCancellationRequested = $CancellationToken.IsCancellationRequested
        }
    }
}

Describe 'Invoke-WintainiumOrchestrationStage' {
    It 'executes a runnable stage and returns its structured result' {
        $state = New-TestOperationState
        $plan = New-TestStagePlan -OperationId $operationId
        $context = New-TestCancellationContext
        $input = [pscustomobject]@{ Value = 'fixture' }
        $executor = {
            param($StageInput, $CancellationToken)
            [pscustomobject]@{ Value = $StageInput.Value; Cancelled = $CancellationToken.IsCancellationRequested }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context; StageInput = $input; StageExecutor = $executor } {
            param($OperationState, $StagePlan, $CancellationContext, $StageInput, $StageExecutor)
            Invoke-WintainiumOrchestrationStage -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput $StageInput -StageExecutor $StageExecutor
        }

        $result.IsSuccessful | Should -BeTrue
        $result.WasCancelled | Should -BeFalse
        $result.OperationId | Should -Be $operationId
        $result.StageSequence | Should -Be 1
        $result.StageName | Should -Be 'ManifestValidation'
        $result.Result.Value | Should -Be 'fixture'
        $result.Result.Cancelled | Should -BeFalse
        $result.Error | Should -BeNullOrEmpty
    }

    It 'propagates the caller cancellation token to the executor' {
        $state = New-TestOperationState
        $plan = New-TestStagePlan -OperationId $operationId
        $source = [System.Threading.CancellationTokenSource]::new()

        try {
            $context = New-TestCancellationContext -CancellationToken $source.Token
            $executor = {
                param($StageInput, $CancellationToken)
                [pscustomobject]@{ CanBeCanceled = $CancellationToken.CanBeCanceled }
            }

            $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context; StageInput = $null; StageExecutor = $executor } {
                param($OperationState, $StagePlan, $CancellationContext, $StageInput, $StageExecutor)
                Invoke-WintainiumOrchestrationStage -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput $StageInput -StageExecutor $StageExecutor
            }

            $result.IsSuccessful | Should -BeTrue
            $result.Result.CanBeCanceled | Should -BeTrue
        }
        finally {
            $source.Dispose()
        }
    }

    It 'does not execute a stage when cancellation is already requested' {
        $state = New-TestOperationState
        $plan = New-TestStagePlan -OperationId $operationId
        $source = [System.Threading.CancellationTokenSource]::new()

        try {
            $source.Cancel()
            $context = New-TestCancellationContext -CancellationToken $source.Token
            $executor = {
                throw 'executor should not run'
            }

            $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context; StageInput = $null; StageExecutor = $executor } {
                param($OperationState, $StagePlan, $CancellationContext, $StageInput, $StageExecutor)
                Invoke-WintainiumOrchestrationStage -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput $StageInput -StageExecutor $StageExecutor
            }

            $result.IsSuccessful | Should -BeFalse
            $result.WasCancelled | Should -BeTrue
            $result.Error.Code | Should -Be 'OrchestrationStageCancelledBeforeExecution'
        }
        finally {
            $source.Dispose()
        }
    }

    It 'rejects a null operation state structurally' {
        $plan = New-TestStagePlan -OperationId $operationId
        $context = New-TestCancellationContext
        $result = InModuleScope Wintainium.Core -Parameters @{ StagePlan = $plan; CancellationContext = $context } {
            param($StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationStage -OperationState $null -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput $null -StageExecutor { param($StageInput, $CancellationToken) }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Error.Code | Should -Be 'OrchestrationStageStateMissing'
    }

    It 'rejects a terminal operation state' {
        $state = New-TestOperationState
        $state.Status = 'Completed'
        $plan = New-TestStagePlan -OperationId $operationId
        $context = New-TestCancellationContext

        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
            param($OperationState, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationStage -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput $null -StageExecutor { param($StageInput, $CancellationToken) }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Error.Code | Should -Be 'OrchestrationStageStateNotRunnable'
    }

    It 'rejects a current-stage mismatch' {
        $state = New-TestOperationState
        $plan = New-TestStagePlan -OperationId $operationId
        $context = New-TestCancellationContext

        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
            param($OperationState, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationStage -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 2 -StageName 'ReleaseDiscovery' -StageInput $null -StageExecutor { param($StageInput, $CancellationToken) }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Error.Code | Should -Be 'OrchestrationStageCurrentStageMismatch'
    }

    It 'rejects an operation identifier mismatch' {
        $state = New-TestOperationState
        $plan = New-TestStagePlan -OperationId ([guid]::NewGuid().ToString())
        $context = New-TestCancellationContext

        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
            param($OperationState, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationStage -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput $null -StageExecutor { param($StageInput, $CancellationToken) }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Error.Code | Should -Be 'OrchestrationStageOperationIdMismatch'
    }

    It 'converts stage executor exceptions into structured failures' {
        $state = New-TestOperationState
        $plan = New-TestStagePlan -OperationId $operationId
        $context = New-TestCancellationContext

        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context } {
            param($OperationState, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationStage -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput $null -StageExecutor { param($StageInput, $CancellationToken) throw 'fixture failure' }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.WasCancelled | Should -BeFalse
        $result.Error.Code | Should -Be 'OrchestrationStageExecutorError'
        $result.Result | Should -BeNullOrEmpty
    }

    It 'does not mutate operation state during stage execution' {
        $state = New-TestOperationState
        $before = $state | ConvertTo-Json -Depth 10
        $plan = New-TestStagePlan -OperationId $operationId
        $context = New-TestCancellationContext
        $executor = { param($StageInput, $CancellationToken) 'ok' }

        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; StagePlan = $plan; CancellationContext = $context; StageExecutor = $executor } {
            param($OperationState, $StagePlan, $CancellationContext, $StageExecutor)
            Invoke-WintainiumOrchestrationStage -OperationState $OperationState -StagePlan $StagePlan -CancellationContext $CancellationContext -StageSequence 1 -StageName 'ManifestValidation' -StageInput $null -StageExecutor $StageExecutor
        }

        $result.IsSuccessful | Should -BeTrue
        ($state | ConvertTo-Json -Depth 10) | Should -Be $before
    }
}
