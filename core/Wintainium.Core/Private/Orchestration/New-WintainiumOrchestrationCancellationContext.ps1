function New-WintainiumOrchestrationCancellationContext {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$OperationState,

        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
    )

    $errors = [System.Collections.Generic.List[object]]::new()

    if ($null -eq $OperationState) {
        $errors.Add([pscustomobject]@{
                Code = 'OrchestrationCancellationStateMissing'
                Message = 'OperationState is required.'
            })
    }
    else {
        $operationIdProperty = $OperationState.PSObject.Properties['OperationId']
        if ($null -eq $operationIdProperty -or [string]::IsNullOrWhiteSpace([string]$operationIdProperty.Value)) {
            $errors.Add([pscustomobject]@{
                    Code = 'OrchestrationCancellationOperationIdMissing'
                    Message = 'OperationState.OperationId is required.'
                })
        }
        else {
            $parsedOperationId = [guid]::Empty
            if (-not [guid]::TryParse([string]$operationIdProperty.Value, [ref]$parsedOperationId)) {
                $errors.Add([pscustomobject]@{
                        Code = 'OrchestrationCancellationOperationIdInvalid'
                        Message = 'OperationState.OperationId must be a valid GUID.'
                    })
            }
        }
    }

    if ($errors.Count -gt 0) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Context = $null
            Errors = $errors.ToArray()
        }
    }

    [pscustomobject][ordered]@{
        IsValid = $true
        Context = [pscustomobject][ordered]@{
            OperationId = [string]$OperationState.OperationId
            CancellationToken = $CancellationToken
            IsCancellationRequested = $CancellationToken.IsCancellationRequested
        }
        Errors = @()
    }
}
