function Invoke-WintainiumProviderSourceResolution {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Request)

    $status = [Uri]$Request.SourceUri | ForEach-Object { $_.AbsolutePath.Trim('/').ToLowerInvariant() }

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
