function Invoke-WintainiumOrchestrationStageOperation {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$OperationState,

        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$StagePlan,

        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$CancellationContext,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483647)]
        [int]$StageSequence,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StageName,

        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$StageInput,

        [AllowNull()]
        [Parameter(Mandatory)]
        [scriptblock]$StageExecutor
    )

    $operationId = if ($null -ne $OperationState -and $OperationState.PSObject.Properties['OperationId']) { [string]$OperationState.OperationId } else { $null }

    $newFailure = {
        param([string]$Code, [string]$Message, [psobject]$ExecutionResult = $null)
        [pscustomobject][ordered]@{
            IsSuccessful = $false
            OperationId = $operationId
            StageSequence = $StageSequence
            StageName = $StageName
            Execution = $ExecutionResult
            State = $OperationState
            Error = [pscustomobject][ordered]@{ Code = $Code; Message = $Message }
        }
    }

    if ($null -eq $OperationState) { return & $newFailure 'OrchestrationStageOperationStateMissing' 'OperationState is required.' }
    if ($null -eq $StagePlan) { return & $newFailure 'OrchestrationStageOperationStagePlanMissing' 'StagePlan is required.' }
    if ($null -eq $CancellationContext) { return & $newFailure 'OrchestrationStageOperationCancellationContextMissing' 'CancellationContext is required.' }
    if ($null -eq $StageExecutor) { return & $newFailure 'OrchestrationStageOperationExecutorMissing' 'StageExecutor is required.' }

    $execution = Invoke-WintainiumOrchestrationStage `
        -OperationState $OperationState `
        -StagePlan $StagePlan `
        -CancellationContext $CancellationContext `
        -StageSequence $StageSequence `
        -StageName $StageName `
        -StageInput $StageInput `
        -StageExecutor $StageExecutor

    if (-not $execution.IsSuccessful) {
        return & $newFailure 'OrchestrationStageExecutionFailed' 'The orchestration stage did not complete successfully.' $execution
    }

    $transition = Update-WintainiumOrchestrationOperationState `
        -State $OperationState `
        -StagePlan $StagePlan `
        -StageSequence $StageSequence `
        -StageName $StageName `
        -StageResult $execution.Result `
        -Succeeded $true

    if (-not $transition.IsValid) {
        return & $newFailure 'OrchestrationStageStateTransitionFailed' 'The stage executed successfully, but its result could not be committed to orchestration state.' $execution
    }

    [pscustomobject][ordered]@{
        IsSuccessful = $true
        OperationId = $operationId
        StageSequence = $StageSequence
        StageName = $StageName
        Execution = $execution
        State = $transition.State
        Error = $null
    }
}
