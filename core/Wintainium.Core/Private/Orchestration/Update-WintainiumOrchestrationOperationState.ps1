function Update-WintainiumOrchestrationOperationState {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$State,

        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$StagePlan,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483647)]
        [int]$StageSequence,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StageName,

        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$StageResult,

        [Parameter(Mandatory)]
        [bool]$Succeeded
    )

    $errors = [System.Collections.Generic.List[object]]::new()

    if ($null -eq $State) {
        $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStateMissing'; Message = 'State is required.' })
    }
    if ($null -eq $StagePlan) {
        $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStatePlanMissing'; Message = 'StagePlan is required.' })
    }

    if ($null -ne $State) {
        foreach ($propertyName in @('OperationId', 'Status', 'CurrentStageSequence', 'CurrentStageName', 'CompletedStages', 'StageResults', 'FailedStage', 'Error')) {
            if ($null -eq $State.PSObject.Properties[$propertyName]) {
                $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStatePropertyMissing'; Message = "State must contain a $propertyName property." })
            }
        }
    }

    if ($null -ne $StagePlan) {
        foreach ($propertyName in @('OperationId', 'Stages')) {
            $property = $StagePlan.PSObject.Properties[$propertyName]
            if ($null -eq $property -or $null -eq $property.Value) {
                $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStatePlanPropertyMissing'; Message = "StagePlan must contain a $propertyName property." })
            }
        }
    }

    if ($errors.Count -gt 0) {
        return [pscustomobject][ordered]@{ IsValid = $false; State = $null; Errors = $errors.ToArray() }
    }

    $parsedStateOperationId = [guid]::Empty
    if (-not [guid]::TryParse([string]$State.OperationId, [ref]$parsedStateOperationId)) {
        $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStateOperationIdInvalid'; Message = 'State.OperationId must be a valid GUID.' })
    }

    $parsedPlanOperationId = [guid]::Empty
    if (-not [guid]::TryParse([string]$StagePlan.OperationId, [ref]$parsedPlanOperationId)) {
        $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStatePlanOperationIdInvalid'; Message = 'StagePlan.OperationId must be a valid GUID.' })
    }

    if ($errors.Count -eq 0 -and -not [string]::Equals([string]$State.OperationId, [string]$StagePlan.OperationId, [System.StringComparison]::OrdinalIgnoreCase)) {
        $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStateOperationIdMismatch'; Message = 'State.OperationId must match StagePlan.OperationId.' })
    }

    $validStatuses = @('Pending', 'Running')
    if ([string]$State.Status -notin $validStatuses) {
        $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStateTerminal'; Message = 'A terminal orchestration state cannot accept another stage result.' })
    }

    if ($null -eq $State.CurrentStageSequence -or [int]$State.CurrentStageSequence -ne $StageSequence) {
        $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStateStageMismatch'; Message = "StageSequence $StageSequence does not match the current stage sequence $($State.CurrentStageSequence)." })
    }
    if (-not [string]::Equals([string]$State.CurrentStageName, $StageName, [System.StringComparison]::Ordinal)) {
        $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStateStageMismatch'; Message = "StageName '$StageName' does not match the current stage name '$($State.CurrentStageName)'." })
    }

    $stages = @($StagePlan.Stages)
    if ($stages.Count -eq 0) {
        $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStatePlanStagesMissing'; Message = 'StagePlan must contain at least one stage.' })
    }
    elseif ($StageSequence -gt $stages.Count) {
        $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStateStageSequenceInvalid'; Message = "StageSequence $StageSequence is not present in StagePlan." })
    }
    else {
        $planStage = $stages[$StageSequence - 1]
        if ($null -eq $planStage) {
            $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStatePlanStageInvalid'; Message = "StagePlan stage $StageSequence is null." })
        }
        else {
            $planSequence = 0
            if (-not [int]::TryParse([string]$planStage.Sequence, [ref]$planSequence) -or $planSequence -ne $StageSequence) {
                $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStatePlanStageSequenceInvalid'; Message = "StagePlan stage $StageSequence must have Sequence $StageSequence." })
            }
            if (-not [string]::Equals([string]$planStage.Name, $StageName, [System.StringComparison]::Ordinal)) {
                $errors.Add([pscustomobject]@{ Code = 'OrchestrationOperationStateStageMismatch'; Message = "StageName '$StageName' does not match the planned stage name '$($planStage.Name)'." })
            }
        }
    }

    if ($errors.Count -gt 0) {
        return [pscustomobject][ordered]@{ IsValid = $false; State = $null; Errors = $errors.ToArray() }
    }

    $completedStages = @($State.CompletedStages) + [pscustomobject][ordered]@{ Sequence = $StageSequence; Name = $StageName }
    $stageResults = @($State.StageResults) + [pscustomobject][ordered]@{ Sequence = $StageSequence; Name = $StageName; Result = $StageResult; Succeeded = $Succeeded }

    if (-not $Succeeded) {
        return [pscustomobject][ordered]@{
            IsValid = $true
            State = [pscustomobject][ordered]@{
                OperationId = [string]$State.OperationId
                Status = 'Failed'
                CurrentStageSequence = $StageSequence
                CurrentStageName = $StageName
                CompletedStages = $completedStages
                StageResults = $stageResults
                FailedStage = [pscustomobject][ordered]@{ Sequence = $StageSequence; Name = $StageName }
                Error = $StageResult
            }
            Errors = @()
        }
    }

    if ($StageSequence -eq $stages.Count) {
        return [pscustomobject][ordered]@{
            IsValid = $true
            State = [pscustomobject][ordered]@{
                OperationId = [string]$State.OperationId
                Status = 'Completed'
                CurrentStageSequence = $null
                CurrentStageName = $null
                CompletedStages = $completedStages
                StageResults = $stageResults
                FailedStage = $null
                Error = $null
            }
            Errors = @()
        }
    }

    $nextStage = $stages[$StageSequence]
    [pscustomobject][ordered]@{
        IsValid = $true
        State = [pscustomobject][ordered]@{
            OperationId = [string]$State.OperationId
            Status = 'Running'
            CurrentStageSequence = [int]$nextStage.Sequence
            CurrentStageName = [string]$nextStage.Name
            CompletedStages = $completedStages
            StageResults = $stageResults
            FailedStage = $null
            Error = $null
        }
        Errors = @()
    }
}
