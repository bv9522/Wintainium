function Invoke-WintainiumProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Request
    )

    switch ($Request.Settings.mode) {
        'empty' {
            return [pscustomobject][ordered]@{
                OperationId = $Request.OperationId
                IsSuccessful = $true
                Status = 'NoReleasesFound'
                Releases = @()
                Errors = @()
                Warnings = @()
                LogEvents = @()
            }
        }
        'failure' {
            return [pscustomobject][ordered]@{
                OperationId = $Request.OperationId
                IsSuccessful = $false
                Status = 'SourceUnavailable'
                Releases = @()
                Errors = @(
                    [pscustomobject][ordered]@{
                        Code = 'ProviderSourceUnavailable'
                        Message = 'Simulated upstream unavailability.'
                    }
                )
                Warnings = @()
                LogEvents = @()
            }
        }
        'throw' {
            throw 'Simulated provider failure.'
        }
        'bad-operation-id' {
            return [pscustomobject][ordered]@{
                OperationId = '00000000-0000-0000-0000-000000000099'
                IsSuccessful = $true
                Status = 'Success'
                Releases = @()
                Errors = @()
                Warnings = @()
                LogEvents = @()
            }
        }
        'bad-release' {
            return [pscustomobject][ordered]@{
                OperationId = $Request.OperationId
                IsSuccessful = $true
                Status = 'Success'
                Releases = @(
                    [pscustomobject][ordered]@{
                        Version = '1.2.3'
                        Artifacts = @()
                    }
                )
                Errors = @()
                Warnings = @()
                LogEvents = @()
            }
        }
        default {
            return [pscustomobject][ordered]@{
                OperationId = $Request.OperationId
                IsSuccessful = $true
                Status = 'Success'
                Releases = @(
                    [pscustomobject][ordered]@{
                        ReleaseId = 'contract-fixture-release-1'
                        Version = '1.2.3'
                        Channel = 'stable'
                        PublishedAt = [DateTimeOffset]'2026-01-01T00:00:00Z'
                        Artifacts = @(
                            [pscustomobject][ordered]@{
                                Uri = 'https://example.invalid/contract-fixture-1.2.3-x64.zip'
                                FileName = 'contract-fixture-1.2.3-x64.zip'
                                Format = 'zip'
                                Architecture = 'x64'
                                Size = 12345
                                Hashes = @(
                                    [pscustomobject][ordered]@{
                                        Algorithm = 'SHA256'
                                        Value = ('a' * 64)
                                    }
                                )
                                Signature = $null
                            }
                        )
                    }
                )
                Errors = @()
                Warnings = @()
                LogEvents = @(
                    [pscustomobject][ordered]@{
                        OperationId = $Request.OperationId
                        Level = 'Information'
                        Message = 'Contract fixture completed.'
                    }
                )
            }
        }
    }
}

Export-ModuleMember -Function Invoke-WintainiumProvider
