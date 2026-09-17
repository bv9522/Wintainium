function Invoke-WintainiumAuthoritativeStateReconciliation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StateRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OperationId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationId,

        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$ReconciliationResult,

        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$PriorState
    )

    $base = {
        param([bool]$IsSuccessful, [string]$Status, [psobject]$State = $null, [bool]$Persisted = $false, [string]$ReasonCode = $null, [object[]]$Errors = @())
        [pscustomobject][ordered]@{
            OperationId = $OperationId
            IsSuccessful = $IsSuccessful
            Status = $Status
            State = $State
            Persisted = $Persisted
            ReasonCode = $ReasonCode
            Errors = @($Errors)
        }
    }

    if ($null -eq $ReconciliationResult) {
        return & $base $false 'Failed' $PriorState $false 'ReconciliationResultMissing' @([pscustomobject]@{ Code='ReconciliationResultMissing'; Message='Reconciliation result is required.' })
    }

    if ([string]$ReconciliationResult.OperationId -ne $OperationId) {
        return & $base $false 'Failed' $PriorState $false 'OperationIdMismatch' @([pscustomobject]@{ Code='ReconciliationResultOperationIdMismatch'; Message='Reconciliation result OperationId does not match the orchestration OperationId.' })
    }

    if (-not [bool]$ReconciliationResult.IsSuccessful) {
        return & $base $false 'Failed' $PriorState $false 'ReconciliationFailed' @($ReconciliationResult.Errors)
    }

    $evidence = $ReconciliationResult.Evidence
    if ($null -eq $evidence) {
        return & $base $true 'Preserved' $PriorState $false 'EvidenceUnavailable' @()
    }

    try {
        $state = Convert-WintainiumReconciliationEvidenceToInstalledState -ApplicationId $ApplicationId -Evidence $evidence
    }
    catch {
        return & $base $false 'Failed' $PriorState $false 'ReconciliationEvidenceInvalid' @([pscustomobject]@{ Code='ReconciliationEvidenceInvalid'; Message=$_.Exception.Message })
    }

    if ($state.InstallationState -eq 'Unknown') {
        return & $base $true 'Preserved' $PriorState $false 'UnknownEvidencePreserved' @()
    }

    try {
        $persistedState = Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $state
    }
    catch {
        return & $base $false 'Failed' $PriorState $false 'InstalledStatePersistenceFailed' @([pscustomobject]@{ Code='InstalledStatePersistenceFailed'; Message=$_.Exception.Message })
    }

    & $base $true 'Persisted' $persistedState $true 'AuthoritativeEvidencePersisted' @()
}
