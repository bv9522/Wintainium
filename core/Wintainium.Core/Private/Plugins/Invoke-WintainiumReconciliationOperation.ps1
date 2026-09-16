function Invoke-WintainiumReconciliationOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$ReconciliationPlugin,
        [Parameter(Mandatory)][object]$Request
    )

    $operationId = [string]$Request.OperationId
    $logEvents = [System.Collections.Generic.List[object]]::new()

    $baseResult = {
        param([bool]$IsSuccessful,[string]$Status,[object]$Evidence=$null,[object[]]$Errors=@(),[object[]]$Warnings=@())
        [pscustomobject][ordered]@{
            OperationId=$operationId
            IsSuccessful=$IsSuccessful
            Status=$Status
            Evidence=$Evidence
            Errors=@($Errors)
            Warnings=@($Warnings)
            LogEvents=$logEvents.ToArray()
        }
    }

    if ($null -eq $Request -or [string]::IsNullOrWhiteSpace($operationId) -or
        [string]::IsNullOrWhiteSpace([string]$Request.ApplicationId) -or
        $null -eq $Request.PSObject.Properties['Manifest']) {
        return & $baseResult $false 'ReconciliationRequestInvalid' $null @([pscustomobject]@{
                Code='ReconciliationRequestInvalid'
                Message='Reconciliation request must contain OperationId, ApplicationId, and Manifest.'
            }) @()
    }

    if ($null -eq $ReconciliationPlugin -or $ReconciliationPlugin.PluginType -ne 'Reconciliation') {
        return & $baseResult $false 'ReconciliationResultInvalid' $null @([pscustomobject]@{
                Code='ReconciliationInvalidPluginType'
                Message='The supplied plugin is not a reconciliation plugin.'
            }) @()
    }

    if ([string]::IsNullOrWhiteSpace([string]$ReconciliationPlugin.EntryPoint)) {
        return & $baseResult $false 'ReconciliationInternalError' $null @([pscustomobject]@{
                Code='ReconciliationEntryPointNotFound'
                Message="Reconciliation plugin '$($ReconciliationPlugin.PluginId)' does not declare an entry point."
            }) @()
    }

    $pluginDirectory = Split-Path -Path $ReconciliationPlugin.DescriptorPath -Parent
    $entryPointName = [IO.Path]::GetFileName([string]$ReconciliationPlugin.EntryPoint)
    $modulePath = Join-Path -Path $pluginDirectory -ChildPath $entryPointName
    try { $resolvedModulePath = (Resolve-Path -LiteralPath $modulePath -ErrorAction Stop).Path }
    catch {
        return & $baseResult $false 'ReconciliationInternalError' $null @([pscustomobject]@{
                Code='ReconciliationEntryPointNotFound'
                Message="Reconciliation entry point '$($ReconciliationPlugin.EntryPoint)' was not found."
            }) @()
    }

    try {
        $module = Get-Module | Where-Object {
            $_.Path -and ((Resolve-Path -LiteralPath $_.Path -ErrorAction SilentlyContinue).Path -eq $resolvedModulePath)
        } | Select-Object -First 1
        if ($null -eq $module) { $module = Import-Module -Name $resolvedModulePath -PassThru -ErrorAction Stop }

        $command = Get-Command -Module $module.Name -Name 'Invoke-WintainiumReconciliation' -CommandType Function -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            return & $baseResult $false 'ReconciliationInternalError' $null @([pscustomobject]@{
                    Code='ReconciliationOperationNotFound'
                    Message="Reconciliation plugin '$($ReconciliationPlugin.PluginId)' does not export Invoke-WintainiumReconciliation."
                }) @()
        }
        $pluginResult = & $command -Request $Request
    }
    catch {
        return & $baseResult $false 'ReconciliationInternalError' $null @([pscustomobject]@{
                Code='ReconciliationInternalError'
                Message=$_.Exception.Message
            }) @()
    }

    if ($null -eq $pluginResult -or @($pluginResult).Count -ne 1) {
        return & $baseResult $false 'ReconciliationResultInvalid' $null @([pscustomobject]@{
                Code='ReconciliationResultInvalid'
                Message='Reconciliation plugin must return exactly one structured result object.'
            }) @()
    }

    foreach ($requiredProperty in @('OperationId','IsSuccessful','Status','Evidence','Errors','Warnings','LogEvents')) {
        if (-not $pluginResult.PSObject.Properties[$requiredProperty]) {
            return & $baseResult $false 'ReconciliationResultInvalid' $null @([pscustomobject]@{
                    Code='ReconciliationResultInvalid'
                    Message="Reconciliation result is missing required property '$requiredProperty'."
                }) @()
        }
    }

    if ([string]$pluginResult.OperationId -ne $operationId) {
        return & $baseResult $false 'ReconciliationResultInvalid' $null @([pscustomobject]@{
                Code='ReconciliationResultOperationIdMismatch'
                Message='Reconciliation result OperationId does not match the Core request OperationId.'
            }) @()
    }

    foreach ($event in @($pluginResult.LogEvents)) {
        if ($null -ne $event -and $event.PSObject.Properties['OperationId'] -and [string]$event.OperationId -ne $operationId) {
            return & $baseResult $false 'ReconciliationResultInvalid' $null @([pscustomobject]@{
                    Code='ReconciliationResultLogCorrelationInvalid'
                    Message='Reconciliation log event OperationId does not match the Core request OperationId.'
                }) @()
        }
        if ($null -ne $event) { $logEvents.Add($event) }
    }

    foreach ($warning in @($pluginResult.Warnings)) {
        if ($null -ne $warning -and $warning.PSObject.Properties['OperationId'] -and [string]$warning.OperationId -ne $operationId) {
            return & $baseResult $false 'ReconciliationResultInvalid' $null @([pscustomobject]@{
                    Code='ReconciliationResultWarningCorrelationInvalid'
                    Message='Reconciliation warning OperationId does not match the Core request OperationId.'
                }) @()
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$pluginResult.Status)) {
        return & $baseResult $false 'ReconciliationResultInvalid' $null @([pscustomobject]@{
                Code='ReconciliationResultInvalid'
                Message='Reconciliation result Status cannot be empty.'
            }) @()
    }

    if ($null -ne $pluginResult.Evidence) {
        foreach ($requiredEvidenceProperty in @('ApplicationId','InstallationState','EvidenceSource')) {
            if (-not $pluginResult.Evidence.PSObject.Properties[$requiredEvidenceProperty]) {
                return & $baseResult $false 'ReconciliationResultInvalid' $null @([pscustomobject]@{
                        Code='ReconciliationEvidenceInvalid'
                        Message="Reconciliation evidence is missing required property '$requiredEvidenceProperty'."
                    }) @()
            }
        }

        if ([string]$pluginResult.Evidence.ApplicationId -ne [string]$Request.ApplicationId) {
            return & $baseResult $false 'ReconciliationResultInvalid' $null @([pscustomobject]@{
                    Code='ReconciliationEvidenceApplicationIdMismatch'
                    Message='Reconciliation evidence ApplicationId does not match the request ApplicationId.'
                }) @()
        }

        if ([string]$pluginResult.Evidence.InstallationState -notin @('Installed','NotInstalled','Unknown')) {
            return & $baseResult $false 'ReconciliationResultInvalid' $null @([pscustomobject]@{
                    Code='ReconciliationEvidenceInstallationStateInvalid'
                    Message='Reconciliation evidence InstallationState must be Installed, NotInstalled, or Unknown.'
                }) @()
        }
    }

    & $baseResult ([bool]$pluginResult.IsSuccessful) ([string]$pluginResult.Status) $pluginResult.Evidence @($pluginResult.Errors) @($pluginResult.Warnings)
}
