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
        $errors.Add([pscustomobject]@{
                Code = 'OrchestrationOperationStateMissing'
                Message = 'State is required.'
            })
    }

    if ($null -eq $StagePlan) {
        $errors.Add([pscustomobject]@{
                Code = 'OrchestrationOperationStateStagePlanMissing'
                Message = 'StagePlan is required.'
            })
    }

    if ($null -ne $State) {
        foreach ($propertyName in @('OperationId', 'Status', 'CurrentStageSequence', 'CurrentStageName', 'CompletedStages', 'StageResults', 'FailedStage', 'Error')) {
            if ($null -eq $State.PSObject.Properties[$propertyName]) {
                $errors.Add([pscustomobject]@{
                        Code = 'OrchestrationOperationStatePropertyMissing'
                        Message = "State must contain a $propertyName property."
                    })
            }
        }

        $parsedOperationId = [guid]::Empty
        if ($null -ne $State.PSObject.Properties['OperationId'] -and
            -not [guid]::TryParse([string]$State.OperationId, [ref]$parsedOperationId)) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateOperationIdInvalid'
                    Message = 'State.OperationId must be a valid GUID.'
                })
        }

        if ($null -ne $State.PSObject.Properties['Status'] -and
            [string]$State.Status -notin @('Pending', 'Running', 'Failed', 'Completed')) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateStatusInvalid'
                    Message = 'State.Status must be Pending, Running, Failed, or Completed.'
                })
        }

        if ($null -ne $State.PSObject.Properties['CurrentStageSequence'] -and
            $null -eq $State.CurrentStageSequence) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateCurrentStageMissing'
                    Message = 'State.CurrentStageSequence is required while an operation is active.'
                })
        }

        if ($null -ne $State.PSObject.Properties['CurrentStageName'] -and
            [string]::IsNullOrWhiteSpace([string]$State.CurrentStageName)) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateCurrentStageMissing'
                    Message = 'State.CurrentStageName is required while an operation is active.'
                })
        }

        if ($null -ne $State.PSObject.Properties['Status'] -and [string]$State.Status -in @('Failed', 'Completed')) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateTerminal'
                    Message = 'A terminal orchestration state cannot accept another stage result.'
                })
        }
        elseif ($null -ne $State.PSObject.Properties['CurrentStageSequence'] -and
            [int]$State.CurrentStageSequence -ne $StageSequence) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateStageMismatch'
                    Message = "StageSequence $StageSequence does not match the current stage sequence $($State.CurrentStageSequence)."
                })
        }
        elseif ($null -ne $State.PSObject.Properties['CurrentStageName'] -and
            -not [string]::Equals([string]$State.CurrentStageName, $StageName, [System.StringComparison]::Ordinal)) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateStageMismatch'
                    Message = "StageName '$StageName' does not match the current stage name '$($State.CurrentStageName)'."
                })
        }
    }

    if ($null -ne $StagePlan) {
        foreach ($propertyName in @('OperationId', 'Stages')) {
            if ($null -eq $StagePlan.PSObject.Properties[$propertyName]) {
                $errors.Add([pscustomobject]@{
                        Code = 'OrchestrationOperationStateStagePlanPropertyMissing'
                        Message = "StagePlan must contain a $propertyName property."
                    })
            }
        }

        if ($null -ne $StagePlan.PSObject.Properties['OperationId'] -and
            $null -ne $State -and
            -not [string]::Equals([string]$State.OperationId, [string]$StagePlan.OperationId, [System.StringComparison]::OrdinalIgnoreCase)) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateOperationIdMismatch'
                    Message = 'State.OperationId must match StagePlan.OperationId.'
                })
        }

        $planStages = @($StagePlan.Stages)
        $plannedStage = $planStages | Where-Object { $null -ne $_ -and [int]$_.Sequence -eq $StageSequence }
        if (@($plannedStage).Count -ne 1) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStatePlannedStageMissing'
                    Message = "StagePlan must contain exactly one stage with sequence $StageSequence."
                })
        }
        else {
            if (-not [string]::Equals([string]$plannedStage.Name, $StageName, [System.StringComparison]::Ordinal)) {
                $errors.Add([pscustomobject]@{
                        Code = 'OrchestrationOperationStateStageMismatch'
                        Message = "StageName '$StageName' does not match the planned stage name '$($plannedStage.Name)'."
                    })
            }
        }
    }

    if ($errors.Count -gt 0) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            State = $null
            Errors = $errors.ToArray()
        }
    }

    $planStages = @($StagePlan.Stages)
    $plannedStage = @($planStages | Where-Object { [int]$_.Sequence -eq $StageSequence })[0]

    $completedStages = @($State.CompletedStages)
    $stageResults = @($State.StageResults)

    $completedStages += [pscustomobject][ordered]@{
        Sequence = $StageSequence
        Name = $StageName
    }
    $stageResults += [pscustomobject][ordered]@{
        Sequence = $StageSequence
        Name = $StageName
        Result = $StageResult
        Succeeded = $Succeeded
    }

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
                FailedStage = [pscustomobject][ordered]@{
                    Sequence = $StageSequence
                    Name = $StageName
                }
                Error = $StageResult
            }
            Errors = @()
        }
    }

    $nextStage = @($planStages | Where-Object { [int]$_.Sequence -eq ($StageSequence + 1) })
    if ($nextStage.Count -eq 0) {
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

    [pscustomobject][ordered]@{
        IsValid = $true
        State = [pscustomobject][ordered]@{
            OperationId = [string]$State.OperationId
            Status = 'Running'
            CurrentStageSequence = [int]$nextStage[0].Sequence
            CurrentStageName = [string]$nextStage[0].Name
            CompletedStages = $completedStages
            StageResults = $stageResults
            FailedStage = $null
            Error = $null
        }
        Errors = @()
    }
}
