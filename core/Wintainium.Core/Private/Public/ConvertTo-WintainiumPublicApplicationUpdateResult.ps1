function ConvertTo-WintainiumPublicApplicationUpdateResult {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$LifecycleResult
    )

    $operationId = if ($null -ne $LifecycleResult.PSObject.Properties['OperationId']) {
        [string]$LifecycleResult.OperationId
    } else {
        $null
    }

    $isSuccessful = if ($null -ne $LifecycleResult.PSObject.Properties['IsSuccessful']) {
        [bool]$LifecycleResult.IsSuccessful
    } else {
        $false
    }

    $wasCancelled = if ($null -ne $LifecycleResult.PSObject.Properties['WasCancelled']) {
        [bool]$LifecycleResult.WasCancelled
    } else {
        $false
    }

    $status = if ($wasCancelled) {
        'Cancelled'
    }
    elseif ($isSuccessful) {
        'Completed'
    }
    else {
        'Failed'
    }

    $applicationId = $null
    $stages = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $logEvents = [System.Collections.Generic.List[object]]::new()

    foreach ($item in @($LifecycleResult.StageResults)) {
        if ($null -eq $item) {
            continue
        }

        $execution = if ($null -ne $item.PSObject.Properties['Execution']) { $item.Execution } else { $null }
        $stage = if ($null -ne $item.PSObject.Properties['Stage']) { $item.Stage } else { $null }
        $result = if ($null -ne $execution -and $execution.PSObject.Properties['Result']) { $execution.Result } else { $null }

        if ($null -eq $stage) {
            $stage = $item
        }

        $sequence = if ($null -ne $stage.PSObject.Properties['Sequence']) { [int]$stage.Sequence } else { 0 }
        $name = if ($null -ne $stage.PSObject.Properties['Name']) { [string]$stage.Name } elseif ($null -ne $item.PSObject.Properties['StageName']) { [string]$item.StageName } else { $null }
        $stageStatus = if ($null -ne $result -and $result.PSObject.Properties['Status']) { [string]$result.Status } elseif ($null -ne $execution -and $execution.PSObject.Properties['Status']) { [string]$execution.Status } else { $null }
        $stageSuccessful = if ($null -ne $result -and $result.PSObject.Properties['IsSuccessful']) { [bool]$result.IsSuccessful } elseif ($null -ne $execution -and $execution.PSObject.Properties['IsSuccessful']) { [bool]$execution.IsSuccessful } else { $false }
        $stageCancelled = if ($null -ne $execution -and $execution.PSObject.Properties['WasCancelled']) { [bool]$execution.WasCancelled } else { $false }
        $stageError = if ($null -ne $result -and $result.PSObject.Properties['Error']) { $result.Error } elseif ($null -ne $execution -and $execution.PSObject.Properties['Error']) { $execution.Error } else { $null }

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
