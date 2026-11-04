function Invoke-WintainiumProviderSourceResolution {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Request)

    $source = $null
    $errors = @()
    $sourcePath = ([Uri]$Request.SourceUri).AbsolutePath.Trim('/').ToLowerInvariant()
    if ($sourcePath -eq 'success-with-errors') {
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
