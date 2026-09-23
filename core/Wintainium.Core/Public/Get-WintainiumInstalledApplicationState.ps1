function Get-WintainiumInstalledApplicationState {
    <#
    .SYNOPSIS
    Reads the authoritative installed state for one managed application.

    .DESCRIPTION
    Reads Core-owned installed application state from the supplied state root.
    Missing state is a successful Unknown observation. Invalid persisted state
    is reported as a structured failure rather than guessed.

    .PARAMETER StateRoot
    Root directory containing the authoritative installed-state store.

    .PARAMETER ApplicationId
    Stable Wintainium application identity corresponding to the manifest Id.

    .OUTPUTS
    PSCustomObject containing OperationId, IsSuccessful, Status, ApplicationId,
    State, Errors, Warnings, and LogEvents.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StateRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationId,

        [string]$OperationId
    )

    $resolvedOperationId = [guid]::Empty
    if ([string]::IsNullOrWhiteSpace($OperationId)) {
        $resolvedOperationId = [guid]::NewGuid()
    }
    elseif (-not [guid]::TryParse($OperationId, [ref]$resolvedOperationId)) {
        return [pscustomobject][ordered]@{
            OperationId = $OperationId
            IsSuccessful = $false
            Status = 'InvalidInput'
            ApplicationId = $ApplicationId
            State = $null
            Errors = @([pscustomobject][ordered]@{
                Code = 'OperationIdInvalid'
                Path = '$.OperationId'
                Message = 'OperationId must be a valid GUID.'
            })
            Warnings = @()
            LogEvents = @()
        }
    }

    $resolvedOperationId = $resolvedOperationId.ToString()

    try {
        $state = Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId $ApplicationId
    }
    catch {
        return [pscustomobject][ordered]@{
            OperationId = $resolvedOperationId
            IsSuccessful = $false
            Status = 'InstalledStateUnavailable'
            ApplicationId = $ApplicationId
            State = $null
            Errors = @([pscustomobject][ordered]@{
                Code = 'InstalledStateReadFailed'
                Path = '$.StateRoot'
                Message = $_.Exception.Message
            })
            Warnings = @()
            LogEvents = @()
        }
    }

    [pscustomobject][ordered]@{
        OperationId = $resolvedOperationId
        IsSuccessful = $true
        Status = [string]$state.InstallationState
        ApplicationId = [string]$state.ApplicationId
        State = $state
        Errors = @()
        Warnings = @()
        LogEvents = @()
    }
}
