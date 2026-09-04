function Update-WintainiumOrchestrationOperationState {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$State,

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
    else {
        foreach ($propertyName in @('OperationId', 'Status', 'CurrentStageSequence', 'CurrentStageName', 'CompletedStages', 'StageResults', 'FailedStage', 'Error')) {
            $property = $State.PSObject.Properties[$propertyName]
            if ($null -eq $property) {
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

        $validStatuses = @('Pending', 'Running', 'Failed', 'Completed')
        if ($null -ne $State.PSObject.Properties['Status'] -and
            [string]$State.Status -notin $validStatuses) {
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

    if ($errors.Count -gt 0) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            State = $null
            Errors = $errors.ToArray()
        }
    }

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

    $nextSequence = $StageSequence + 1

    if ($nextSequence -gt @($State.StageResults, $State.CompletedStages).Count) {
        # The stage plan is not carried by state, so terminal status is determined
        # by the absence of a known next stage only when the current result is the
        # final recorded sequence. This branch is replaced below using the state
        # plan sequence marker when present.
    }

    $nextStageSequence = $null
    $nextStageName = $null
    $planStageCountProperty = $State.PSObject.Properties['StageCount']
    if ($null -ne $planStageCountProperty -and $null -ne $planStageCountProperty.Value) {
        $stageCount = [int]$planStageCountProperty.Value
        if ($StageSequence -lt $stageCount) {
            $nextStageSequence = $nextSequence
            $nextStageName = "Stage$nextSequence"
        }
    }

    if ($null -eq $nextStageSequence) {
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
            CurrentStageSequence = $nextStageSequence
            CurrentStageName = $nextStageName
            CompletedStages = $completedStages
            StageResults = $stageResults
            FailedStage = $null
            Error = $null
        }
        Errors = @()
    }
}
