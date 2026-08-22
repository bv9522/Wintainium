function Invoke-WintainiumProviderOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Provider,

        [Parameter(Mandatory)]
        [object]$Request
    )

    $operationId = [string]$Request.OperationId
    $logEvents = [System.Collections.Generic.List[object]]::new()

    $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationStarted' -Message 'Provider operation started.' -Context @{ ProviderId = $Provider.PluginId }))

    $baseResult = {
        param(
            [bool]$IsSuccessful,
            [string]$Status,
            [object[]]$Releases = @(),
            [object[]]$Errors = @(),
            [object[]]$Warnings = @()
        )

        [pscustomobject][ordered]@{
            OperationId = $operationId
            IsSuccessful = $IsSuccessful
            Status = $Status
            Releases = @($Releases)
            Errors = @($Errors)
            Warnings = @($Warnings)
            LogEvents = $logEvents.ToArray()
        }
    }

    if ($Provider.PluginType -ne 'Provider') {
        $error = [pscustomobject]@{ Code = 'ProviderOperationInvalidPluginType'; Message = 'The supplied plugin is not a provider.' }
        $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message $error.Message -Context @{ ErrorCode = $error.Code }))
        return & $baseResult $false 'ProviderResultInvalid' @() @($error) @()
    }

    if ([string]::IsNullOrWhiteSpace($Provider.EntryPoint)) {
        $error = [pscustomobject]@{ Code = 'ProviderEntryPointNotFound'; Message = "Provider '$($Provider.PluginId)' does not declare an entry point." }
        $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message $error.Message -Context @{ ErrorCode = $error.Code }))
        return & $baseResult $false 'ProviderInternalError' @() @($error) @()
    }

    $providerDirectory = Split-Path -Path $Provider.DescriptorPath -Parent
    $entryPointName = [IO.Path]::GetFileName($Provider.EntryPoint)
    $modulePath = Join-Path -Path $providerDirectory -ChildPath $entryPointName
    $resolvedModulePath = $null

    try {
        $resolvedModulePath = (Resolve-Path -LiteralPath $modulePath -ErrorAction Stop).Path
    }
    catch {
        $error = [pscustomobject]@{ Code = 'ProviderEntryPointNotFound'; Message = "Provider entry point '$($Provider.EntryPoint)' was not found." }
        $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message $error.Message -Context @{ ErrorCode = $error.Code }))
        return & $baseResult $false 'ProviderInternalError' @() @($error) @()
    }

    try {
        $module = Import-Module -Name $resolvedModulePath -Force -PassThru -ErrorAction Stop
        $command = Get-Command -Module $module.Name -Name 'Invoke-WintainiumProvider' -CommandType Function -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            $error = [pscustomobject]@{ Code = 'ProviderOperationNotFound'; Message = "Provider '$($Provider.PluginId)' does not export Invoke-WintainiumProvider." }
            $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message $error.Message -Context @{ ErrorCode = $error.Code }))
            return & $baseResult $false 'ProviderInternalError' @() @($error) @()
        }

        $providerResult = & $command -Request $Request
    }
    catch {
        $error = [pscustomobject]@{ Code = 'ProviderInternalError'; Message = $_.Exception.Message }
        $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message 'Provider execution failed.' -Context @{ ErrorCode = $error.Code }))
        return & $baseResult $false 'ProviderInternalError' @() @($error) @()
    }

    if ($null -eq $providerResult -or @($providerResult).Count -ne 1) {
        $error = [pscustomobject]@{ Code = 'ProviderResultInvalid'; Message = 'Provider must return exactly one structured result object.' }
        $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message $error.Message -Context @{ ErrorCode = $error.Code }))
        return & $baseResult $false 'ProviderResultInvalid' @() @($error) @()
    }

    if (-not $providerResult.PSObject.Properties['OperationId'] -or [string]$providerResult.OperationId -ne $operationId) {
        $error = [pscustomobject]@{ Code = 'ProviderResultOperationIdMismatch'; Message = 'Provider result OperationId does not match the Core request OperationId.' }
        $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message $error.Message -Context @{ ErrorCode = $error.Code }))
        return & $baseResult $false 'ProviderResultInvalid' @() @($error) @()
    }

    foreach ($requiredProperty in @('IsSuccessful', 'Status', 'Releases', 'Errors', 'Warnings', 'LogEvents')) {
        if (-not $providerResult.PSObject.Properties[$requiredProperty]) {
            $error = [pscustomobject]@{ Code = 'ProviderResultInvalid'; Message = "Provider result is missing required property '$requiredProperty'." }
            $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message $error.Message -Context @{ ErrorCode = $error.Code }))
            return & $baseResult $false 'ProviderResultInvalid' @() @($error) @()
        }
    }

    foreach ($providerLogEvent in @($providerResult.LogEvents)) {
        if ($null -ne $providerLogEvent -and $providerLogEvent.PSObject.Properties['OperationId']) {
            if ([string]$providerLogEvent.OperationId -ne $operationId) {
                $error = [pscustomobject]@{ Code = 'ProviderResultLogCorrelationInvalid'; Message = 'Provider log event OperationId does not match the Core request OperationId.' }
                $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message $error.Message -Context @{ ErrorCode = $error.Code }))
                return & $baseResult $false 'ProviderResultInvalid' @() @($error) @()
            }
        }
        $logEvents.Add($providerLogEvent)
    }

    $releases = @($providerResult.Releases)
    foreach ($release in $releases) {
        if ($null -eq $release -or
            -not $release.PSObject.Properties['ReleaseId'] -or [string]::IsNullOrWhiteSpace([string]$release.ReleaseId) -or
            -not $release.PSObject.Properties['Version'] -or [string]::IsNullOrWhiteSpace([string]$release.Version) -or
            -not $release.PSObject.Properties['Channel'] -or [string]::IsNullOrWhiteSpace([string]$release.Channel) -or
            -not $release.PSObject.Properties['Artifacts']) {
            $error = [pscustomobject]@{ Code = 'ProviderResultReleaseInvalid'; Message = 'Provider result contains a release that does not satisfy the normalized release contract.' }
            $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message $error.Message -Context @{ ErrorCode = $error.Code }))
            return & $baseResult $false 'ProviderResultInvalid' @() @($error) @()
        }
    }

    foreach ($warning in @($providerResult.Warnings)) {
        if ($null -ne $warning -and $warning.PSObject.Properties['OperationId']) {
            if ([string]$warning.OperationId -ne $operationId) {
                $error = [pscustomobject]@{ Code = 'ProviderResultWarningCorrelationInvalid'; Message = 'Provider warning OperationId does not match the Core request OperationId.' }
                $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message $error.Message -Context @{ ErrorCode = $error.Code }))
                return & $baseResult $false 'ProviderResultInvalid' @() @($error) @()
            }
        }
    }

    $status = [string]$providerResult.Status
    if ([string]::IsNullOrWhiteSpace($status)) {
        $error = [pscustomobject]@{ Code = 'ProviderResultInvalid'; Message = 'Provider result Status cannot be empty.' }
        $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationFailed' -Message $error.Message -Context @{ ErrorCode = $error.Code }))
        return & $baseResult $false 'ProviderResultInvalid' @() @($error) @()
    }

    $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $operationId -Component 'Provider' -EventName 'ProviderOperationCompleted' -Message 'Provider operation completed.' -Context @{ ProviderId = $Provider.PluginId; Status = $status; ReleaseCount = $releases.Count }))

    & $baseResult ([bool]$providerResult.IsSuccessful) $status $releases @($providerResult.Errors) @($providerResult.Warnings)
}
