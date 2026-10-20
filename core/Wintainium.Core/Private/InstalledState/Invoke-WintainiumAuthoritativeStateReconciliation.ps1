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
        param(
            [bool]$IsSuccessful,
            [string]$Status,
            [psobject]$State = $null,
            [bool]$Persisted = $false,
            [string]$ReasonCode = $null,
            [object[]]$Errors = @(),
            [object[]]$Warnings = @()
        )
        [pscustomobject][ordered]@{
            OperationId = $OperationId
            IsSuccessful = $IsSuccessful
            Status = $Status
            State = $State
            Persisted = $Persisted
            ReasonCode = $ReasonCode
            Errors = @($Errors)
            Warnings = @($Warnings)
        }
    }

    if ($null -eq $ReconciliationResult) {
        return & $base $false 'Failed' $PriorState $false 'ReconciliationResultMissing' @([pscustomobject]@{ Code='ReconciliationResultMissing'; Message='Reconciliation result is required.' })
    }

    if ([string]$ReconciliationResult.OperationId -ne $OperationId) {
        return & $base $false 'Failed' $PriorState $false 'OperationIdMismatch' @([pscustomobject]@{ Code='ReconciliationResultOperationIdMismatch'; Message='Reconciliation result OperationId does not match the orchestration OperationId.' })
    }

    if (-not [bool]$ReconciliationResult.IsSuccessful) {
        return & $base $false 'Failed' $PriorState $false 'ReconciliationFailed' @($ReconciliationResult.Errors) @($ReconciliationResult.Warnings)
    }

    $evidence = $ReconciliationResult.Evidence
    if ($null -eq $evidence) {
        $warning = [pscustomobject][ordered]@{
            Code = 'ReconciliationEvidenceUnavailable'
            Path = '$.Evidence'
            Message = 'Reconciliation completed without installed-state evidence. The prior state was preserved and no state was persisted.'
        }
        return & $base $true 'Preserved' $PriorState $false 'EvidenceUnavailable' @() (@($ReconciliationResult.Warnings) + @($warning))
    }

    try {
        $state = Convert-WintainiumReconciliationEvidenceToInstalledState -ApplicationId $ApplicationId -Evidence $evidence
    }
    catch {
        return & $base $false 'Failed' $PriorState $false 'ReconciliationEvidenceInvalid' @([pscustomobject]@{ Code='ReconciliationEvidenceInvalid'; Message=$_.Exception.Message }) @($ReconciliationResult.Warnings)
    }

    if ($state.InstallationState -eq 'Unknown') {
        $warning = [pscustomobject][ordered]@{
            Code = 'UnknownEvidencePreserved'
            Path = '$.Evidence.InstallationState'
            Message = 'Reconciliation returned Unknown. The prior installed-state observation was preserved and no state was persisted.'
        }
        return & $base $true 'Preserved' $PriorState $false 'UnknownEvidencePreserved' @() (@($ReconciliationResult.Warnings) + @($warning))
    }

    try {
        $persistedState = Set-WintainiumInstalledApplicationState -StateRoot $StateRoot -State $state
    }
    catch {
        return & $base $false 'Failed' $PriorState $false 'InstalledStatePersistenceFailed' @([pscustomobject]@{ Code='InstalledStatePersistenceFailed'; Message=$_.Exception.Message }) @($ReconciliationResult.Warnings)
    }

    & $base $true 'Persisted' $persistedState $true 'AuthoritativeEvidencePersisted' @() @($ReconciliationResult.Warnings)
}
