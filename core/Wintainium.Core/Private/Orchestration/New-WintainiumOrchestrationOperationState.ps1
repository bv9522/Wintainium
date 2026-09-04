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
                Code = 'OrchestrationOperationStatePlanMissing'
                Message = 'StagePlan is required.'
            })
    }
    else {
        foreach ($propertyName in @('OperationId', 'Stages')) {
            $property = $StagePlan.PSObject.Properties[$propertyName]
            if ($null -eq $property -or $null -eq $property.Value) {
                $errors.Add([pscustomobject]@{
                        Code = 'OrchestrationOperationStatePlanPropertyMissing'
                        Message = "StagePlan must contain a $propertyName property."
                    })
            }
        }

        $operationId = [string]$StagePlan.OperationId
        $parsedOperationId = [guid]::Empty
        if (-not [guid]::TryParse($operationId, [ref]$parsedOperationId)) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateOperationIdInvalid'
                    Message = 'StagePlan.OperationId must be a valid GUID.'
                })
        }

        $stages = @($StagePlan.Stages)
        if ($stages.Count -eq 0) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationOperationStateStagesMissing'
                    Message = 'StagePlan must contain at least one stage.'
                })
        }
        else {
            for ($index = 0; $index -lt $stages.Count; $index++) {
                $stage = $stages[$index]
                if ($null -eq $stage) {
                    $errors.Add([pscustomobject]@{
                            Code = 'OrchestrationOperationStateStageInvalid'
                            Message = "StagePlan stage at index $index is null."
                        })
                    continue
                }

                foreach ($propertyName in @('Sequence', 'Name', 'Required')) {
                    $property = $stage.PSObject.Properties[$propertyName]
                    if ($null -eq $property -or $null -eq $property.Value) {
                        $errors.Add([pscustomobject]@{
                                Code = 'OrchestrationOperationStateStagePropertyMissing'
                                Message = "StagePlan stage at index $index must contain a $propertyName property."
                            })
                    }
                }

                if ($null -ne $stage.PSObject.Properties['Sequence']) {
                    $sequence = 0
                    if (-not [int]::TryParse([string]$stage.Sequence, [ref]$sequence) -or $sequence -ne ($index + 1)) {
                        $errors.Add([pscustomobject]@{
                                Code = 'OrchestrationOperationStateStageSequenceInvalid'
                                Message = "StagePlan stage at index $index must have Sequence $($index + 1)."
                            })
                    }
                }

                if ($null -ne $stage.PSObject.Properties['Name'] -and [string]::IsNullOrWhiteSpace([string]$stage.Name)) {
                    $errors.Add([pscustomobject]@{
                            Code = 'OrchestrationOperationStateStageNameInvalid'
                            Message = "StagePlan stage at index $index must have a non-empty Name."
                        })
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

    $stages = @($StagePlan.Stages)
    $firstStage = $stages[0]

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
