function New-WintainiumInstallationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowNull()] [psobject]$Invocation,
        [Parameter(Mandatory)] [AllowNull()] [psobject]$ProcessResult
    )

    $emptyResult = {
        param([string]$FailureKind,[string]$Message)
        [pscustomobject][ordered]@{
            Status='Failed'
            FailureKind=$FailureKind
            OperationId=if ($null -ne $Invocation -and $Invocation.PSObject.Properties.Name -contains 'OperationId') { $Invocation.OperationId } else { $null }
            DownloadOperationId=if ($null -ne $Invocation -and $Invocation.PSObject.Properties.Name -contains 'DownloadOperationId') { $Invocation.DownloadOperationId } else { $null }
            PluginId=if ($null -ne $Invocation -and $Invocation.PSObject.Properties.Name -contains 'PluginId') { $Invocation.PluginId } else { $null }
            ExitCode=$null
            StandardOutput=''
            StandardError=''
            DurationMilliseconds=0
            ErrorMessage=$Message
            Error=[pscustomobject][ordered]@{
                Code=$FailureKind
                Message=$Message
                FailureKind=$FailureKind
                ErrorMessage=$Message
            }
        }
    }

    if ($null -eq $Invocation) {
        return [pscustomobject][ordered]@{
            Status='Failed'
            FailureKind='InvalidInput'
            OperationId=$null
            DownloadOperationId=$null
            PluginId=$null
            ExitCode=$null
            StandardOutput=''
            StandardError=''
            DurationMilliseconds=0
            ErrorMessage='Installation result requires an installer invocation.'
            Error=[pscustomobject][ordered]@{
                Code='InvalidInput'
                Message='Installation result requires an installer invocation.'
                FailureKind='InvalidInput'
                ErrorMessage='Installation result requires an installer invocation.'
            }
        }
    }

    if ($null -eq $ProcessResult) {
        return & $emptyResult 'InvalidProcessResult' 'Installation result requires a controlled process result.'
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
    $pluginModulePath = if ($Invocation.PSObject.Properties.Name -contains 'PluginModulePath') { [string]$Invocation.PluginModulePath } else { $null }
    $artifactPath = if ($Invocation.PSObject.Properties.Name -contains 'ArtifactPath') { [string]$Invocation.ArtifactPath } else { $null }
    $artifactFormat = if ($Invocation.PSObject.Properties.Name -contains 'ArtifactFormat') { [string]$Invocation.ArtifactFormat } else { $null }

    if ($status -eq 'Completed' -and $exitCode -is [int] -and $exitCode -eq 0) {
        return [pscustomobject][ordered]@{
            Status='Completed'
            FailureKind=$null
            OperationId=$operationId
            DownloadOperationId=$downloadOperationId
            PluginId=$pluginId
            ExitCode=$exitCode
            StandardOutput=$standardOutput
            StandardError=$standardError
            DurationMilliseconds=$duration
            ErrorMessage=$null
            Error=$null
        }
    }

    $resolvedFailureKind = if ([string]::IsNullOrWhiteSpace([string]$failureKind)) { 'ProcessFailed' } else { [string]$failureKind }
    $diagnosticMessage = @(
        "Installer execution failed."
        "FailureKind: $resolvedFailureKind"
        "PluginId: $(if ([string]::IsNullOrWhiteSpace($pluginId)) { 'unknown' } else { $pluginId })"
        "OperationId: $(if ([string]::IsNullOrWhiteSpace([string]$operationId)) { 'unknown' } else { $operationId })"
        "DownloadOperationId: $(if ([string]::IsNullOrWhiteSpace([string]$downloadOperationId)) { 'unknown' } else { $downloadOperationId })"
        "PluginModulePath: $(if ([string]::IsNullOrWhiteSpace($pluginModulePath)) { 'unknown' } else { $pluginModulePath })"
        "ArtifactFormat: $(if ([string]::IsNullOrWhiteSpace($artifactFormat)) { 'unknown' } else { $artifactFormat })"
        "ArtifactPath: $(if ([string]::IsNullOrWhiteSpace($artifactPath)) { 'unknown' } else { $artifactPath })"
        "ExitCode: $(if ($null -eq $exitCode) { 'null' } else { $exitCode })"
        "DurationMilliseconds: $duration"
        "ErrorMessage: $(if ([string]::IsNullOrWhiteSpace([string]$errorMessage)) { 'none' } else { [string]$errorMessage })"
        "StandardError: $(if ([string]::IsNullOrWhiteSpace($standardError)) { 'empty' } else { $standardError })"
        "StandardOutput: $(if ([string]::IsNullOrWhiteSpace($standardOutput)) { 'empty' } else { $standardOutput })"
    ) -join [Environment]::NewLine

    [pscustomobject][ordered]@{
        Status='Failed'
        FailureKind=$resolvedFailureKind
        OperationId=$operationId
        DownloadOperationId=$downloadOperationId
        PluginId=$pluginId
        ExitCode=$exitCode
        StandardOutput=$standardOutput
        StandardError=$standardError
        DurationMilliseconds=$duration
        ErrorMessage=$errorMessage
        Error=[pscustomobject][ordered]@{
            Code=$resolvedFailureKind
            Message=$diagnosticMessage
            FailureKind=$resolvedFailureKind
            ErrorMessage=$errorMessage
            ExitCode=$exitCode
            DurationMilliseconds=$duration
            StandardError=$standardError
            StandardOutput=$standardOutput
            PluginId=$pluginId
            PluginModulePath=$pluginModulePath
            ArtifactFormat=$artifactFormat
            ArtifactPath=$artifactPath
            OperationId=$operationId
            DownloadOperationId=$downloadOperationId
        }
    }
}
