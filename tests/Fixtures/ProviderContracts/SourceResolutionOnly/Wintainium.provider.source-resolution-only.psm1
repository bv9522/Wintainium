function Invoke-WintainiumProviderSourceResolution {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Request)

    $source = $null
    $errors = @()
    if ([Uri]$Request.SourceUri | ForEach-Object { $_.AbsolutePath.Trim('/').ToLowerInvariant() } -eq 'success-with-errors') {
        $source = [pscustomobject][ordered]@{
            ApplicationId = 'fixture.source-resolution-only'
            Name = 'Fixture Source'
            CanonicalUri = 'https://source-resolution-only.example/product'
            ProviderId = 'Wintainium.provider.source-resolution-only'
            ProviderContractVersion = '1'
            ProviderSettings = [ordered]@{ product = 'product' }
        }
        $errors = @([pscustomobject][ordered]@{
            Code = 'FixtureUnexpectedError'
            Message = 'The fixture returns an error alongside a successful result.'
        })
    }

    [pscustomobject][ordered]@{
        OperationId = $Request.OperationId
        IsSuccessful = $true
        Status = 'Resolved'
        Source = $source
        Errors = @($errors)
        Warnings = @()
        LogEvents = @()
    }
}

Export-ModuleMember -Function Invoke-WintainiumProviderSourceResolution
