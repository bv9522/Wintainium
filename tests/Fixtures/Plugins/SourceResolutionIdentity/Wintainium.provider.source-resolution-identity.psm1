function Invoke-WintainiumProviderSourceResolution {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Request)

    $uri = [Uri]$Request.SourceUri
    if ($uri.Host -ne 'identity.example') {
        return [pscustomobject][ordered]@{
            OperationId = $Request.OperationId
            IsSuccessful = $false
            Status = 'SourceUnsupported'
            Source = $null
            Errors = @([pscustomobject]@{ Code='FixtureSourceUnsupported'; Message='The fixture handles only identity.example.' })
            Warnings = @()
            LogEvents = @()
        }
    }

    $providerId = 'Wintainium.provider.source-resolution-identity'
    $contractVersion = '1'
    if ($uri.AbsolutePath -eq '/provider-mismatch') {
        $providerId = 'Wintainium.provider.unrelated'
    }
    elseif ($uri.AbsolutePath -eq '/contract-mismatch') {
        $contractVersion = '2'
    }

    $source = [pscustomobject][ordered]@{
        ApplicationId = 'web.identity.example.product'
        Name = 'Identity Product'
        CanonicalUri = 'https://identity.example/product'
        ProviderId = $providerId
        ProviderContractVersion = $contractVersion
        ProviderSettings = [ordered]@{ product='product' }
    }

    [pscustomobject][ordered]@{
        OperationId = $Request.OperationId
        IsSuccessful = $true
        Status = 'Resolved'
        Source = $source
        Errors = @()
        Warnings = @()
        LogEvents = @()
    }
}

Export-ModuleMember -Function Invoke-WintainiumProviderSourceResolution
