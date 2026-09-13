function Invoke-WintainiumOrchestrationLifecycle {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$Request,

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

    $operationId = if ($null -ne $Request -and $Request.PSObject.Properties['OperationId']) { [string]$Request.OperationId } else { $null }

    $newFailure = {
        param([string]$Code, [string]$Message, [psobject]$State = $null, [object[]]$StageResults = @())
        [pscustomobject][ordered]@{
            IsSuccessful = $false
            WasCancelled = $false
            OperationId = $operationId
            Request = $Request
            State = $State
            StageResults = @($StageResults)
            Error = [pscustomobject][ordered]@{ Code = $Code; Message = $Message }
        }
    }

    if ($null -eq $Request) { return & $newFailure 'OrchestrationLifecycleRequestMissing' 'Request is required.' }
    if ($null -eq $StagePlan) { return & $newFailure 'OrchestrationLifecycleStagePlanMissing' 'StagePlan is required.' }
    if ($null -eq $CancellationContext) { return & $newFailure 'OrchestrationLifecycleCancellationContextMissing' 'CancellationContext is required.' }
    if ($null -eq $StageFactory) { return & $newFailure 'OrchestrationLifecycleStageFactoryMissing' 'StageFactory is required.' }

    foreach ($propertyName in @('OperationId', 'ManifestPath', 'MachineArchitecture', 'DownloadRoot')) {
        if ($null -eq $Request.PSObject.Properties[$propertyName] -or [string]::IsNullOrWhiteSpace([string]$Request.$propertyName)) {
            return & $newFailure 'OrchestrationLifecycleRequestInvalid' "Request must contain a non-empty $propertyName property."
        }
    }

    foreach ($propertyName in @('OperationId', 'Stages')) {
        if ($null -eq $StagePlan.PSObject.Properties[$propertyName] -or $null -eq $StagePlan.$propertyName) {
            return & $newFailure 'OrchestrationLifecycleStagePlanInvalid' "StagePlan must contain a $propertyName property."
        }
    }

    if (-not [string]::Equals([string]$Request.OperationId, [string]$StagePlan.OperationId, [System.StringComparison]::OrdinalIgnoreCase)) {
        return & $newFailure 'OrchestrationLifecycleOperationIdMismatch' 'Request.OperationId must match StagePlan.OperationId.'
    }

    foreach ($propertyName in @('OperationId', 'CancellationToken')) {
        if ($null -eq $CancellationContext.PSObject.Properties[$propertyName]) {
            return & $newFailure 'OrchestrationLifecycleCancellationContextInvalid' "CancellationContext must contain a $propertyName property."
        }
    }

    if (-not [string]::Equals([string]$Request.OperationId, [string]$CancellationContext.OperationId, [System.StringComparison]::OrdinalIgnoreCase)) {
        return & $newFailure 'OrchestrationLifecycleOperationIdMismatch' 'Request.OperationId must match CancellationContext.OperationId.'
    }

    $stateResult = New-WintainiumOrchestrationOperationState -StagePlan $StagePlan
    if ($null -eq $stateResult -or -not $stateResult.IsValid -or $null -eq $stateResult.State) {
        $stateError = if ($null -ne $stateResult -and @($stateResult.Errors).Count -gt 0) { @($stateResult.Errors)[0] } else { $null }
        $message = if ($null -ne $stateError) { [string]$stateError.Message } else { 'The orchestration operation state could not be initialized.' }
        return & $newFailure 'OrchestrationLifecycleStateInitializationFailed' $message
    }

    $state = $stateResult.State
    $workflow = Invoke-WintainiumOrchestrationWorkflow `
        -OperationState $state `
        -StagePlan $StagePlan `
        -CancellationContext $CancellationContext `
        -StageFactory $StageFactory

    if ($null -eq $workflow) {
        return & $newFailure 'OrchestrationLifecycleWorkflowResultMissing' 'The orchestration workflow returned no result.' $state
    }

    [pscustomobject][ordered]@{
        IsSuccessful = [bool]$workflow.IsSuccessful
        WasCancelled = [bool]$workflow.WasCancelled
        OperationId = $operationId
        Request = $Request
        State = $workflow.State
        StageResults = @($workflow.StageResults)
        Error = $workflow.Error
    }
}
