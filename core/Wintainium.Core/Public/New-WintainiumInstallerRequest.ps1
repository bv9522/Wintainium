function New-WintainiumInstallerRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$DownloadResult,

        [Parameter(Mandatory)]
        [psobject]$Manifest
    )

    $validation = Test-WintainiumInstallerInput -DownloadResult $DownloadResult -Manifest $Manifest
    if (-not $validation.IsValid) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Request = $null
            Errors = @($validation.Errors)
        }
    }

    [pscustomobject][ordered]@{
        IsValid = $true
        Request = [pscustomobject][ordered]@{
            OperationId = [guid]::NewGuid().ToString()
            DownloadOperationId = $DownloadResult.OperationId
            Manifest = $Manifest
            Installer = $Manifest.Installer
            Artifact = [pscustomobject][ordered]@{
                Uri = $DownloadResult.Uri
                FileName = $DownloadResult.FileName
                Path = $DownloadResult.DestinationPath
            }
        }
        Errors = @()
    }
}
