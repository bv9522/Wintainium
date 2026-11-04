function Invoke-WintainiumProviderSourceResolution {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Request)

    $status = [Uri]$Request.SourceUri | ForEach-Object { $_.AbsolutePath.Trim('/').ToLowerInvariant() }

    if ($Request.SourceUri -match '^https://github\.com/owner/fault(?:/|$)') {
        return [pscustomobject][ordered]@{
            OperationId = $Request.OperationId
            IsSuccessful = $false
            Status = 'SourceUnavailable'
            Source = $null
            Errors = @([pscustomobject][ordered]@{
                Code = 'SourceResolutionFixtureTransientFailure'
                Message = 'The fixture simulates a transient failure from a competing source resolver.'
            })
            Warnings = @()
            LogEvents = @()
        }
    }

    if ($Request.SourceUri -match '^https://github\.com/owner/ambiguous(?:/|$)') {
        return [pscustomobject][ordered]@{
            OperationId = $Request.OperationId
            IsSuccessful = $false
            Status = 'SourceAmbiguous'
            Source = $null
            Errors = @([pscustomobject][ordered]@{
                Code = 'SourceResolutionFixtureAmbiguous'
                Message = 'The fixture reports multiple possible identities for this source.'
            })
            Warnings = @()
            LogEvents = @()
        }
    }

    $messages = @{
        unsupported = 'The source family is not supported by this provider.'
        ambiguous = 'The source could not be mapped to one unique application.'
        unavailable = 'The upstream source is temporarily unavailable.'
        authentication = 'The source requires authentication.'
        interactive = 'The source requires interactive browser resolution.'
        'response-invalid' = 'The source response did not contain a valid deterministic identity.'
    }

    $map = @{
        'unsupported' = 'SourceUnsupported'
        'ambiguous' = 'SourceAmbiguous'
        'unavailable' = 'SourceUnavailable'
        'authentication' = 'AuthenticationRequired'
        'interactive' = 'InteractiveResolutionRequired'
        'response-invalid' = 'SourceResponseInvalid'
    }

    if ($map.ContainsKey($status)) {
        return [pscustomobject][ordered]@{
            OperationId = $Request.OperationId
            IsSuccessful = $false
            Status = $map[$status]
            Source = $null
            Errors = @([pscustomobject][ordered]@{
                Code = 'SourceResolutionFixtureFailure'
                Message = $messages[$status]
            })
            Warnings = @()
            LogEvents = @()
        }
    }

    return [pscustomobject][ordered]@{
        OperationId = $Request.OperationId
        IsSuccessful = $false
        Status = 'SourceUnsupported'
        Source = $null
        Errors = @([pscustomobject][ordered]@{
            Code = 'SourceResolutionFixtureUnsupported'
            Message = 'The source resolution failure fixture does not resolve arbitrary source URLs.'
        })
        Warnings = @()
        LogEvents = @()
    }
}

Export-ModuleMember -Function Invoke-WintainiumProviderSourceResolution
