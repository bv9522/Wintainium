function Invoke-WintainiumOrchestrationWorkflow {
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

        [AllowNull()]
        [Parameter(Mandatory)]
        [scriptblock]$StageFactory
    )

    $operationId = if ($null -ne $OperationState -and $OperationState.PSObject.Properties['OperationId']) { [string]$OperationState.OperationId } else { $null }

    $newFailure = {
        param([string]$Code, [string]$Message, [psobject]$StateResult = $OperationState, [object[]]$StageResults = @())
        [pscustomobject][ordered]@{
            IsSuccessful = $false
            WasCancelled = $false
            OperationId = $operationId
            State = $StateResult
            StageResults = @($StageResults)
            Error = [pscustomobject][ordered]@{ Code = $Code; Message = $Message }
        }
    }

    if ($null -eq $OperationState) { return & $newFailure 'OrchestrationWorkflowStateMissing' 'OperationState is required.' }
    if ($null -eq $StagePlan) { return & $newFailure 'OrchestrationWorkflowStagePlanMissing' 'StagePlan is required.' }
    if ($null -eq $CancellationContext) { return & $newFailure 'OrchestrationWorkflowCancellationContextMissing' 'CancellationContext is required.' }
    if ($null -eq $StageFactory) { return & $newFailure 'OrchestrationWorkflowStageFactoryMissing' 'StageFactory is required.' }

    $stageResults = [System.Collections.Generic.List[object]]::new()
    $state = $OperationState
    $cancellationToken = $CancellationContext.CancellationToken

    $stages = @($StagePlan.Stages)
    if ($stages.Count -eq 0) { return & $newFailure 'OrchestrationWorkflowStagePlanEmpty' 'StagePlan must contain at least one stage.' }

    foreach ($stage in $stages) {
        if ($null -eq $stage) {
            return & $newFailure 'OrchestrationWorkflowStageDescriptorInvalid' 'StagePlan contains a null stage descriptor.' $state $stageResults.ToArray()
        }

        $stageSequenceProperty = $stage.PSObject.Properties['Sequence']
        $stageNameProperty = $stage.PSObject.Properties['Name']
        if ($null -eq $stageSequenceProperty -or $null -eq $stageNameProperty) {
            return & $newFailure 'OrchestrationWorkflowStageDescriptorInvalid' 'Each stage descriptor must contain Sequence and Name.' $state $stageResults.ToArray()
        }

        $stageSequence = [int]$stage.Sequence
        $stageName = [string]$stage.Name

        if ($null -eq $state -or $state.Status -eq 'Failed' -or $state.Status -eq 'Completed') {
            return & $newFailure 'OrchestrationWorkflowStateTerminal' 'The supplied operation state is already terminal.' $state $stageResults.ToArray()
        }

        if ($state.CurrentStageSequence -ne $stageSequence -or $state.CurrentStageName -cne $stageName) {
            return & $newFailure 'OrchestrationWorkflowCurrentStageMismatch' 'The workflow stage does not match the current operation state stage.' $state $stageResults.ToArray()
        }

        if ($cancellationToken.IsCancellationRequested) {
            return [pscustomobject][ordered]@{
                IsSuccessful = $false
                WasCancelled = $true
                OperationId = $operationId
                State = $state
                StageResults = @($stageResults.ToArray())
                Error = [pscustomobject][ordered]@{ Code = 'OrchestrationWorkflowCancelled'; Message = 'The orchestration workflow was cancelled before the next stage started.' }
            }
        }

        try {
            $binding = & $StageFactory $stage $state $CancellationContext
        }
        catch {
            return & $newFailure 'OrchestrationWorkflowStageFactoryFailed' 'The stage factory failed to provide stage execution inputs.' $state $stageResults.ToArray()
        }

        if ($null -eq $binding) {
            return & $newFailure 'OrchestrationWorkflowStageBindingMissing' 'StageFactory must return a stage binding.' $state $stageResults.ToArray()
        }

        $stageInputProperty = $binding.PSObject.Properties['StageInput']
        $stageExecutorProperty = $binding.PSObject.Properties['StageExecutor']
        if ($null -eq $stageInputProperty -or $null -eq $stageExecutorProperty -or $null -eq $binding.StageExecutor) {
            return & $newFailure 'OrchestrationWorkflowStageBindingInvalid' 'Stage binding must contain StageInput and StageExecutor.' $state $stageResults.ToArray()
        }

        if ($cancellationToken.IsCancellationRequested) {
            return [pscustomobject][ordered]@{
                IsSuccessful = $false
                WasCancelled = $true
                OperationId = $operationId
                State = $state
                StageResults = @($stageResults.ToArray())
                Error = [pscustomobject][ordered]@{ Code = 'OrchestrationWorkflowCancelled'; Message = 'The orchestration workflow was cancelled before the stage execution boundary was entered.' }
            }
        }

        $stageOperation = Invoke-WintainiumOrchestrationStageOperation `
            -OperationState $state `
            -StagePlan $StagePlan `
            -CancellationContext $CancellationContext `
            -StageSequence $stageSequence `
            -StageName $stageName `
            -StageInput $binding.StageInput `
            -StageExecutor $binding.StageExecutor

        $stageResults.Add($stageOperation)

        if ($stageOperation.WasCancelled -or ($stageOperation.Execution -and $stageOperation.Execution.WasCancelled)) {
            return [pscustomobject][ordered]@{
                IsSuccessful = $false
                WasCancelled = $true
                OperationId = $operationId
                State = $state
                StageResults = @($stageResults.ToArray())
                Error = [pscustomobject][ordered]@{ Code = 'OrchestrationWorkflowCancelled'; Message = 'The orchestration workflow was cancelled during stage execution.' }
            }
        }

        if (-not $stageOperation.IsSuccessful) {
            return [pscustomobject][ordered]@{
                IsSuccessful = $false
                WasCancelled = $false
                OperationId = $operationId
                State = $stageOperation.State
                StageResults = @($stageResults.ToArray())
                Error = $stageOperation.Error
            }
        }

        $state = $stageOperation.State
    }

    [pscustomobject][ordered]@{
        IsSuccessful = ($state.Status -eq 'Completed')
        WasCancelled = $false
        OperationId = $operationId
        State = $state
        StageResults = @($stageResults.ToArray())
        Error = if ($state.Status -eq 'Completed') { $null } else { [pscustomobject][ordered]@{ Code = 'OrchestrationWorkflowIncomplete'; Message = 'The workflow exhausted its stage plan without reaching Completed state.' } }
    }
}
