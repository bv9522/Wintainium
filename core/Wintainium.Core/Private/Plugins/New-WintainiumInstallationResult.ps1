function New-WintainiumInstallationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Invocation,
        [Parameter(Mandatory)] [psobject]$ProcessResult
    )

    if ($null -eq $Invocation) {
        return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='InvalidInput'; OperationId=$null; DownloadOperationId=$null; PluginId=$null; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=0; ErrorMessage='Installation result requires an installer invocation.' }
    }
    if ($null -eq $ProcessResult) {
        return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='InvalidProcessResult'; OperationId=if ($Invocation.PSObject.Properties.Name -contains 'OperationId') { $Invocation.OperationId } else { $null }; DownloadOperationId=if ($Invocation.PSObject.Properties.Name -contains 'DownloadOperationId') { $Invocation.DownloadOperationId } else { $null }; PluginId=if ($Invocation.PSObject.Properties.Name -contains 'PluginId') { $Invocation.PluginId } else { $null }; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=0; ErrorMessage='Installation result requires a controlled process result.' }
    }

    $status = if ($ProcessResult.PSObject.Properties.Name -contains 'Status') { [string]$ProcessResult.Status } else { '' }
    $failureKind = if ($ProcessResult.PSObject.Properties.Name -contains 'FailureKind') { $ProcessResult.FailureKind } else { $null }
    $exitCode = if ($ProcessResult.PSObject.Properties.Name -contains 'ExitCode') { $ProcessResult.ExitCode } else { $null }
    $standardOutput = if ($ProcessResult.PSObject.Properties.Name -contains 'StandardOutput' -and $null -ne $ProcessResult.StandardOutput) { [string]$ProcessResult.StandardOutput } else { '' }
    $standardError = if ($ProcessResult.PSObject.Properties.Name -contains 'StandardError' -and $null -ne $ProcessResult.StandardError) { [string]$ProcessResult.StandardError } else { '' }
    $duration = if ($ProcessResult.PSObject.Properties.Name -contains 'DurationMilliseconds') { $ProcessResult.DurationMilliseconds } else { 0 }
    $errorMessage = if ($ProcessResult.PSObject.Properties.Name -contains 'ErrorMessage') { $ProcessResult.ErrorMessage } else { $null }
    $operationId = if ($Invocation.PSObject.Properties.Name -contains 'OperationId') { $Invocation.OperationId } else { $null }
    $downloadOperationId = if ($Invocation.PSObject.Properties.Name -contains 'DownloadOperationId') { $Invocation.DownloadOperationId } else { $null }
    $pluginId = if ($Invocation.PSObject.Properties.Name -contains 'PluginId') { $Invocation.PluginId } else { $null }

    if ($status -eq 'Completed' -and $exitCode -eq 0) {
        return [pscustomobject][ordered]@{ Status='Completed'; FailureKind=$null; OperationId=$operationId; DownloadOperationId=$downloadOperationId; PluginId=$pluginId; ExitCode=$exitCode; StandardOutput=$standardOutput; StandardError=$standardError; DurationMilliseconds=$duration; ErrorMessage=$null }
    }

    return [pscustomobject][ordered]@{ Status='Failed'; FailureKind=if ([string]::IsNullOrWhiteSpace([string]$failureKind)) { 'ProcessFailed' } else { [string]$failureKind }; OperationId=$operationId; DownloadOperationId=$downloadOperationId; PluginId=$pluginId; ExitCode=$exitCode; StandardOutput=$standardOutput; StandardError=$standardError; DurationMilliseconds=$duration; ErrorMessage=$errorMessage }
}
