$script:WintainiumOriginalApplicationUpdateLifecycle = (Get-Command Invoke-WintainiumApplicationUpdateLifecycle -CommandType Function).ScriptBlock

function Invoke-WintainiumApplicationUpdateLifecycle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$ManifestPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$StateRoot,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$MachineArchitecture,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$DownloadRoot,
        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),
        [ValidateRange(1, 2147483647)] [int]$InstallerTimeoutMilliseconds = 600000,
        [System.Net.Http.HttpClient]$HttpClient,
        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
    )

    $result = & $script:WintainiumOriginalApplicationUpdateLifecycle @PSBoundParameters
    if ($null -eq $result -or -not [bool]$result.IsSuccessful) {
        return $result
    }

    $decisionStage = @($result.StageResults | Where-Object { [string]$_.StageName -eq 'UpdateDecision' } | Select-Object -Last 1)
    if ($decisionStage.Count -eq 0 -or $null -eq $decisionStage[0].Execution -or $null -eq $decisionStage[0].Execution.Result) {
        return $result
    }

    $decision = $decisionStage[0].Execution.Result
    if ([string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) {
        return $result
    }

    $reconciliationStage = @($result.StageResults | Where-Object { [string]$_.StageName -eq 'Reconciliation' } | Select-Object -Last 1)
    if ($reconciliationStage.Count -eq 0 -or $null -eq $reconciliationStage[0].Execution -or $null -eq $reconciliationStage[0].Execution.Result) {
        return $result
    }

    $reconciliationResult = $reconciliationStage[0].Execution.Result
    $priorState = Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId ([string]$decision.SelectedRelease.ApplicationId)
    if ($null -eq $priorState -or [string]::IsNullOrWhiteSpace([string]$priorState.ApplicationId)) {
        $priorState = Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId ([string]$result.StageResults[0].Execution.Result.Manifest.Id)
    }

    $authoritative = Invoke-WintainiumAuthoritativeStateReconciliation `
        -StateRoot $StateRoot `
        -OperationId ([string]$result.OperationId) `
        -ApplicationId ([string]$result.StageResults[0].Execution.Result.Manifest.Id) `
        -ReconciliationResult $reconciliationResult `
        -PriorState $priorState

    $reconciliationStage[0].Execution.Result | Add-Member -NotePropertyName AuthoritativeStateResult -NotePropertyValue $authoritative -Force
    if (-not [bool]$authoritative.IsSuccessful) {
        $result.IsSuccessful = $false
        $result.Error = [pscustomobject][ordered]@{ Code='AuthoritativeStateReconciliationFailed'; Message='Authoritative installed state reconciliation failed.'; Detail=$authoritative }
        $result.State.Status = 'Failed'
        $result.State.FailedStage = [pscustomobject][ordered]@{ Name='Reconciliation' }
    }

    return $result
}
