function Invoke-WintainiumOrchestrationStage {
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

    $newFailure = {
        param(
            [string]$Code,
            [string]$Message,
            [bool]$WasCancelled = $false
        )

        [pscustomobject][ordered]@{
            IsSuccessful = $false
            WasCancelled = $WasCancelled
            OperationId = if ($null -ne $OperationState -and $OperationState.PSObject.Properties['OperationId']) { [string]$OperationState.OperationId } else { $null }
            StageSequence = $StageSequence
            StageName = $StageName
            Result = $null
            Error = [pscustomobject][ordered]@{
                Code = $Code
                Message = $Message
            }
        }
    }

    if ($null -eq $OperationState) {
        return & $newFailure 'OrchestrationStageStateMissing' 'OperationState is required.'
    }

    if ($null -eq $StagePlan) {
        return & $newFailure 'OrchestrationStagePlanMissing' 'StagePlan is required.'
    }

    if ($null -eq $CancellationContext) {
        return & $newFailure 'OrchestrationStageCancellationContextMissing' 'CancellationContext is required.'
    }

    if ($null -eq $StageExecutor) {
        return & $newFailure 'OrchestrationStageExecutorMissing' 'StageExecutor is required.'
    }

    $stateOperationIdProperty = $OperationState.PSObject.Properties['OperationId']
    $stateStatusProperty = $OperationState.PSObject.Properties['Status']
    $stateSequenceProperty = $OperationState.PSObject.Properties['CurrentStageSequence']
    $stateNameProperty = $OperationState.PSObject.Properties['CurrentStageName']
    if ($null -eq $stateOperationIdProperty -or $null -eq $stateStatusProperty -or $null -eq $stateSequenceProperty -or $null -eq $stateNameProperty) {
        return & $newFailure 'OrchestrationStageStateMalformed' 'OperationState is missing required properties.'
    }

    $operationId = [guid]::Empty
    if (-not [guid]::TryParse([string]$stateOperationIdProperty.Value, [ref]$operationId)) {
        return & $newFailure 'OrchestrationStageOperationIdInvalid' 'OperationState.OperationId must be a valid GUID.'
    }

    if ([string]$stateStatusProperty.Value -notin @('Pending', 'Running')) {
        return & $newFailure 'OrchestrationStageStateNotRunnable' 'OperationState must be Pending or Running to execute a stage.'
    }

    if ([int]$stateSequenceProperty.Value -ne $StageSequence -or [string]$stateNameProperty.Value -ne $StageName) {
        return & $newFailure 'OrchestrationStageCurrentStageMismatch' 'The requested stage must match the current operation state stage.'
    }

    $planOperationIdProperty = $StagePlan.PSObject.Properties['OperationId']
    $planStagesProperty = $StagePlan.PSObject.Properties['Stages']
    if ($null -eq $planOperationIdProperty -or $null -eq $planStagesProperty) {
        return & $newFailure 'OrchestrationStagePlanMalformed' 'StagePlan is missing required properties.'
    }

    $planOperationId = [guid]::Empty
    if (-not [guid]::TryParse([string]$planOperationIdProperty.Value, [ref]$planOperationId)) {
        return & $newFailure 'OrchestrationStagePlanOperationIdInvalid' 'StagePlan.OperationId must be a valid GUID.'
    }

    if ($planOperationId -ne $operationId) {
        return & $newFailure 'OrchestrationStageOperationIdMismatch' 'OperationState and StagePlan must use the same OperationId.'
    }

    $plannedMatches = @($planStagesProperty.Value | Where-Object { $_ -ne $null -and $_.PSObject.Properties['Sequence'] -and $_.PSObject.Properties['Name'] -and [int]$_.Sequence -eq $StageSequence })
    if ($plannedMatches.Count -ne 1) {
        return & $newFailure 'OrchestrationStagePlanStageMissing' 'StagePlan must contain exactly one stage matching the requested sequence.'
    }

    if ([string]$plannedMatches[0].Name -ne $StageName) {
        return & $newFailure 'OrchestrationStagePlanStageMismatch' 'The requested stage name must match the authoritative StagePlan.'
    }

    $contextOperationIdProperty = $CancellationContext.PSObject.Properties['OperationId']
    $contextTokenProperty = $CancellationContext.PSObject.Properties['CancellationToken']
    if ($null -eq $contextOperationIdProperty -or $null -eq $contextTokenProperty) {
        return & $newFailure 'OrchestrationStageCancellationContextMalformed' 'CancellationContext is missing required properties.'
    }

    $contextOperationId = [guid]::Empty
    if (-not [guid]::TryParse([string]$contextOperationIdProperty.Value, [ref]$contextOperationId)) {
        return & $newFailure 'OrchestrationStageCancellationOperationIdInvalid' 'CancellationContext.OperationId must be a valid GUID.'
    }

    if ($contextOperationId -ne $operationId) {
        return & $newFailure 'OrchestrationStageCancellationOperationIdMismatch' 'OperationState and CancellationContext must use the same OperationId.'
    }

    $token = $contextTokenProperty.Value
    if ($token -isnot [System.Threading.CancellationToken]) {
        return & $newFailure 'OrchestrationStageCancellationTokenInvalid' 'CancellationContext.CancellationToken must be a CancellationToken.'
    }

    if ($token.IsCancellationRequested) {
        return & $newFailure 'OrchestrationStageCancelledBeforeExecution' 'The stage was cancelled before execution began.' $true
    }

    try {
        $stageResult = & $StageExecutor -StageInput $StageInput -CancellationToken $token

        return [pscustomobject][ordered]@{
            IsSuccessful = $true
            WasCancelled = $false
            OperationId = [string]$operationId
            StageSequence = $StageSequence
            StageName = $StageName
            Result = $stageResult
            Error = $null
        }
    }
    catch {
        return [pscustomobject][ordered]@{
            IsSuccessful = $false
            WasCancelled = $false
            OperationId = [string]$operationId
            StageSequence = $StageSequence
            StageName = $StageName
            Result = $null
            Error = [pscustomobject][ordered]@{
                Code = 'OrchestrationStageExecutorError'
                Message = 'The orchestration stage executor failed.'
            }
        }
    }
}
