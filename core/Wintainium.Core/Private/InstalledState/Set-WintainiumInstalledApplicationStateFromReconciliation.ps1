function Set-WintainiumInstalledApplicationStateFromReconciliation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$StateRoot,
        [Parameter(Mandatory)] [ValidateNotNull()] [psobject]$ReconciliationResult
    )
    $operationId = if ($null -ne $ReconciliationResult.PSObject.Properties['OperationId']) { [string]$ReconciliationResult.OperationId } else { '' }
    $base = { param([bool]$successful,[string]$status,[object]$state,[object[]]$errors)
        [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$successful; Status=$status; State=$state; Errors=@($errors) }
    }
    $guid = [guid]::Empty
    if ([string]::IsNullOrWhiteSpace($operationId) -or -not [guid]::TryParse($operationId, [ref]$guid)) {
        return & $base $false 'InvalidInput' $null @([pscustomobject]@{ Code='ReconciliationStateOperationIdInvalid'; Message='Reconciliation result OperationId must be a valid GUID.' })
    }
    foreach ($property in @('IsSuccessful','Status','Evidence')) {
        if ($null -eq $ReconciliationResult.PSObject.Properties[$property]) {
            return & $base $false 'InvalidInput' $null @([pscustomobject]@{ Code='ReconciliationResultPropertyMissing'; Property=$property; Message="Reconciliation result is missing required property '$property'." })
        }
    }
    if (-not [bool]$ReconciliationResult.IsSuccessful) {
        return & $base $false 'ReconciliationNotApplied' $null @([pscustomobject]@{ Code='ReconciliationResultUnsuccessful'; Message='An unsuccessful reconciliation result cannot update authoritative installed state.' })
    }
    $evidence = $ReconciliationResult.Evidence
    if ($null -eq $evidence) { return & $base $false 'InvalidInput' $null @([pscustomobject]@{ Code='ReconciliationEvidenceMissing'; Message='A successful reconciliation result must contain evidence before state can be updated.' }) }
    foreach ($property in @('ApplicationId','InstallationState','EvidenceSource')) {
        if ($null -eq $evidence.PSObject.Properties[$property]) { return & $base $false 'InvalidInput' $null @([pscustomobject]@{ Code='ReconciliationEvidencePropertyMissing'; Property=$property; Message="Reconciliation evidence is missing required property '$property'." }) }
    }
    if ([string]$evidence.InstallationState -notin @('Installed','NotInstalled','Unknown')) { return & $base $false 'InvalidInput' $null @([pscustomobject]@{ Code='ReconciliationEvidenceInstallationStateInvalid'; Message='Reconciliation evidence InstallationState must be Installed, NotInstalled, or Unknown.' }) }
    if ([string]::IsNullOrWhiteSpace([string]$evidence.ApplicationId)) { return & $base $false 'InvalidInput' $null @([pscustomobject]@{ Code='ReconciliationEvidenceApplicationIdInvalid'; Message='Reconciliation evidence ApplicationId must be non-empty.' }) }
    $version = if ($null -ne $evidence.PSObject.Properties['Version']) { [string]$evidence.Version } else { '' }
    $versionSource = if ($null -ne $evidence.PSObject.Properties['VersionSource']) { [string]$evidence.VersionSource } else { '' }
    $installationLocation = if ($null -ne $evidence.PSObject.Properties['InstallationLocation']) { [string]$evidence.InstallationLocation } else { '' }
    if ([string]$evidence.InstallationState -eq 'NotInstalled') { $version=''; $versionSource=''; $installationLocation='' }
    try {
        $state = New-WintainiumInstalledApplicationState -ApplicationId ([string]$evidence.ApplicationId) -InstallationState ([string]$evidence.InstallationState) -Version $version -VersionSource $versionSource -Architecture 'unknown' -Channel 'unknown' -InstallationLocation $installationLocation
        $saved = Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $state
        return & $base $true 'StateUpdated' $saved @()
    } catch {
        return & $base $false 'StateUpdateFailed' $null @([pscustomobject]@{ Code='ReconciliationStateUpdateFailed'; Message=$_.Exception.Message })
    }
}