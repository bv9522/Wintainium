function New-WintainiumOrchestrationOperationState {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$StagePlan
    )

    $errors = [System.Collections.Generic.List[object]]::new()

    if ($null -eq $StagePlan) {
        $errors.Add([pscustomobject]@{
                Code = 'OrchestrationOperationStateStagePlanMissing'
                Message = 'StagePlan is required.'
            })
    }
    else {
        foreach ($propertyName in @('OperationId', 'Stages')) {
            $property = $StagePlan.PSObject.Properties[$propertyName]
            if ($null -eq $property -or $null -eq $property.Value) {
                $errors.Add([pscustomobject]@{
                        Code = 'OrchestrationOperationStateStagePlanPropertyMissing'
                        Message = "StagePlan must contain a $propertyName property."
                    })
            }
        }

        $parsedOperationId = [guid]::Empty
        if ($null -ne $StagePlan.PSObject.Properties['OperationId'] -and
            -not [guid]::TryParse([string]$StagePlan.OperationId, [ref]$parsedOperationId)) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateOperationIdInvalid'
                    Message = 'StagePlan.OperationId must be a valid GUID.'
                })
        }

        $stages = @($StagePlan.Stages)
        if ($stages.Count -eq 0) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateStagesMissing'
                    Message = 'StagePlan.Stages must contain at least one stage.'
                })
        }
        else {
            for ($index = 0; $index -lt $stages.Count; $index++) {
                $stage = $stages[$index]
                if ($null -eq $stage) {
                    $errors.Add([pscustomobject]@{
                            Code = 'OrchestrationOperationStateStageInvalid'
                            Message = "StagePlan.Stages[$index] is required."
                        })
                    continue
                }

                foreach ($propertyName in @('Sequence', 'Name')) {
                    $property = $stage.PSObject.Properties[$propertyName]
                    if ($null -eq $property -or $null -eq $property.Value -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                        $errors.Add([pscustomobject]@{
                                Code = 'OrchestrationOperationStateStageInvalid'
                                Message = "StagePlan.Stages[$index] must contain a non-empty $propertyName property."
                            })
                    }
                }

                if ($null -ne $stage.PSObject.Properties['Sequence']) {
                    $expectedSequence = $index + 1
                    if ([int]$stage.Sequence -ne $expectedSequence) {
                        $errors.Add([pscustomobject]@{
                                Code = 'OrchestrationOperationStateStageSequenceInvalid'
                                Message = "StagePlan.Stages[$index].Sequence must be $expectedSequence."
                            })
                    }
                }
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

    $firstStage = @($StagePlan.Stages)[0]

    [pscustomobject][ordered]@{
        IsValid = $true
        State = [pscustomobject][ordered]@{
            OperationId = [string]$StagePlan.OperationId
            Status = 'Pending'
            CurrentStageSequence = [int]$firstStage.Sequence
            CurrentStageName = [string]$firstStage.Name
            CompletedStages = @()
            StageResults = @()
            FailedStage = $null
            Error = $null
        }
        Errors = @()
    }
}
