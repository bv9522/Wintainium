function ConvertTo-WintainiumPublicApplicationUpdateResult {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$LifecycleResult
    )

    $operationId = if ($null -ne $LifecycleResult.PSObject.Properties['OperationId']) { [string]$LifecycleResult.OperationId } else { $null }
    $isSuccessful = if ($null -ne $LifecycleResult.PSObject.Properties['IsSuccessful']) { [bool]$LifecycleResult.IsSuccessful } else { $false }
    $wasCancelled = if ($null -ne $LifecycleResult.PSObject.Properties['WasCancelled']) { [bool]$LifecycleResult.WasCancelled } else { $false }

    $status = if ($wasCancelled) { 'Cancelled' } elseif ($isSuccessful) { 'Completed' } else { 'Failed' }

    $applicationId = $null
    $stages = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $logEvents = [System.Collections.Generic.List[object]]::new()

    foreach ($item in @($LifecycleResult.StageResults)) {
        if ($null -eq $item) { continue }

        $execution = if ($null -ne $item.PSObject.Properties['Execution']) { $item.Execution } else { $null }
        $stage = if ($null -ne $item.PSObject.Properties['Stage']) { $item.Stage } else { $null }
        $result = if ($null -ne $execution -and $execution.PSObject.Properties['Result']) { $execution.Result } else { $null }

        if ($null -eq $stage) { $stage = $item }

        $sequence = if ($null -ne $stage.PSObject.Properties['Sequence']) {
            [int]$stage.Sequence
        } elseif ($null -ne $item.PSObject.Properties['StageSequence']) {
            [int]$item.StageSequence
        } else {
            0
        }

        $name = if ($null -ne $stage.PSObject.Properties['Name']) {
            [string]$stage.Name
        } elseif ($null -ne $item.PSObject.Properties['StageName']) {
            [string]$item.StageName
        } else {
            $null
        }

        $stageStatus = if ($null -ne $result -and $result.PSObject.Properties['Status']) {
            [string]$result.Status
        } elseif ($null -ne $execution -and $execution.PSObject.Properties['Status']) {
            [string]$execution.Status
        } else {
            $null
        }

        $stageSuccessful = if ($null -ne $result -and $result.PSObject.Properties['IsSuccessful']) {
            [bool]$result.IsSuccessful
        } elseif ($null -ne $execution -and $execution.PSObject.Properties['IsSuccessful']) {
            [bool]$execution.IsSuccessful
        } else {
            $false
        }

        $stageCancelled = if ($null -ne $execution -and $execution.PSObject.Properties['WasCancelled']) {
            [bool]$execution.WasCancelled
        } else {
            $false
        }

        $stageErrorCandidates = [System.Collections.Generic.List[object]]::new()
        if ($null -ne $result -and $result.PSObject.Properties['Error'] -and $null -ne $result.Error) {
            $stageErrorCandidates.Add($result.Error)
        }
        if ($null -ne $execution -and $execution.PSObject.Properties['Error'] -and $null -ne $execution.Error) {
            $stageErrorCandidates.Add($execution.Error)
            if ($execution.Error.PSObject.Properties['Detail'] -and $null -ne $execution.Error.Detail) {
                $stageErrorCandidates.Add($execution.Error.Detail)
            }
        }
        if ($null -ne $result -and
            $null -ne $result.PSObject.Properties['ErrorMessage'] -and
            -not [string]::IsNullOrWhiteSpace([string]$result.ErrorMessage)) {
            $stageErrorCandidates.Add([pscustomobject][ordered]@{
                Code = if ($result.PSObject.Properties['FailureKind'] -and -not [string]::IsNullOrWhiteSpace([string]$result.FailureKind)) { [string]$result.FailureKind } else { 'OrchestrationStageStructuredFailure' }
                Message = [string]$result.ErrorMessage
                FailureKind = if ($result.PSObject.Properties['FailureKind']) { [string]$result.FailureKind } else { $null }
                ErrorMessage = [string]$result.ErrorMessage
            })
        }
        if ($null -ne $item.PSObject.Properties['Error'] -and $null -ne $item.Error) {
            $stageErrorCandidates.Add($item.Error)
        }

        $stageError = $stageErrorCandidates | Where-Object {
            $message = if ($_.PSObject.Properties['Message']) { [string]$_.Message } else { $null }
            $code = if ($_.PSObject.Properties['Code']) { [string]$_.Code } else { $null }
            -not (
                [string]::Equals($code, 'OrchestrationStageExecutionFailed', [System.StringComparison]::OrdinalIgnoreCase) -or
                ([string]::Equals($code, 'OrchestrationStageStructuredFailure', [System.StringComparison]::OrdinalIgnoreCase) -and
                 [string]::Equals($message, 'The stage returned a structured unsuccessful result.', [System.StringComparison]::OrdinalIgnoreCase))
            )
        } | Select-Object -First 1

        if ($null -eq $stageError -and $stageErrorCandidates.Count -gt 0) {
            $stageError = $stageErrorCandidates[0]
        }

        if ($null -eq $applicationId -and $null -ne $result -and $result.PSObject.Properties['Manifest'] -and $null -ne $result.Manifest) {
            if ($result.Manifest.PSObject.Properties['Id']) {
                $applicationId = [string]$result.Manifest.Id
            }
        }

        $stages.Add([pscustomobject][ordered]@{
            Sequence = $sequence
            Name = $name
            Status = $stageStatus
            IsSuccessful = $stageSuccessful
            WasCancelled = $stageCancelled
            Error = $stageError
        })

        if ($null -ne $result) {
            foreach ($collectionName in @('Errors','Warnings','LogEvents')) {
                if ($result.PSObject.Properties[$collectionName]) {
                    foreach ($entry in @($result.$collectionName)) {
                        if ($null -ne $entry) {
                            switch ($collectionName) {
                                'Errors' { $errors.Add($entry) }
                                'Warnings' { $warnings.Add($entry) }
                                'LogEvents' { $logEvents.Add($entry) }
                            }
                        }
                    }
                }
            }
        }

        if ($null -ne $stageError) {
            $errors.Add($stageError)
        }
    }

    if ($null -ne $LifecycleResult.PSObject.Properties['Error'] -and $null -ne $LifecycleResult.Error) {
        $errors.Add($LifecycleResult.Error)
    }

    [pscustomobject][ordered]@{
        OperationId = $operationId
        IsSuccessful = $isSuccessful
        WasCancelled = $wasCancelled
        Status = $status
        ApplicationId = $applicationId
        Stages = @($stages.ToArray())
        Errors = @($errors.ToArray())
        Warnings = @($warnings.ToArray())
        LogEvents = @($logEvents.ToArray())
        Error = if ($null -ne $LifecycleResult.PSObject.Properties['Error']) { $LifecycleResult.Error } else { $null }
    }
}