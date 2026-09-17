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
    if ($null -eq $result -or -not [bool]$result.IsSuccessful) { return $result }

    $manifestStage = @($result.StageResults | Where-Object { [string]$_.StageName -eq 'ManifestValidation' } | Select-Object -Last 1)
    $decisionStage = @($result.StageResults | Where-Object { [string]$_.StageName -eq 'UpdateDecision' } | Select-Object -Last 1)
    $reconciliationStage = @($result.StageResults | Where-Object { [string]$_.StageName -eq 'Reconciliation' } | Select-Object -Last 1)
    if ($manifestStage.Count -eq 0 -or $decisionStage.Count -eq 0 -or $reconciliationStage.Count -eq 0) { return $result }
    if ($null -eq $manifestStage[0].Execution.Result -or $null -eq $decisionStage[0].Execution.Result -or $null -eq $reconciliationStage[0].Execution.Result) { return $result }

    $manifest = $manifestStage[0].Execution.Result.Manifest
    $decision = $decisionStage[0].Execution.Result
    if ($null -eq $manifest -or [string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) { return $result }

    $reconciliationResult = $reconciliationStage[0].Execution.Result
    $applicationId = [string]$manifest.Id
    $priorState = Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId $applicationId
    $authoritative = Invoke-WintainiumAuthoritativeStateReconciliation `
        -StateRoot $StateRoot `
        -OperationId ([string]$result.OperationId) `
        -ApplicationId $applicationId `
        -ReconciliationResult $reconciliationResult `
        -PriorState $priorState

    $reconciliationStage[0].Execution.Result | Add-Member -NotePropertyName AuthoritativeStateResult -NotePropertyValue $authoritative -Force
    if (-not [bool]$authoritative.IsSuccessful) {
        $result.IsSuccessful = $false
        $result | Add-Member -NotePropertyName Error -NotePropertyValue ([pscustomobject][ordered]@{ Code='AuthoritativeStateReconciliationFailed'; Message='Authoritative installed state reconciliation failed.'; Detail=$authoritative }) -Force
        if ($null -ne $result.State) {
            $result.State.Status = 'Failed'
            $result.State | Add-Member -NotePropertyName FailedStage -NotePropertyValue ([pscustomobject][ordered]@{ Name='Reconciliation' }) -Force
        }
    }

    return $result
}
