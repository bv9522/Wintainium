function New-WintainiumInstallerRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$DownloadResult,
        [Parameter(Mandatory)] [psobject]$Manifest,
        [string]$OperationId
    )

    $validation = Test-WintainiumInstallerInput -DownloadResult $DownloadResult -Manifest $Manifest
    if (-not $validation.IsValid) {
        return [pscustomobject][ordered]@{ IsValid=$false; Request=$null; Errors=@($validation.Errors) }
    }

    $resolvedOperationId = if ([string]::IsNullOrWhiteSpace($OperationId)) {
        [guid]::NewGuid().ToString()
    } else {
        $parsed = [guid]::Empty
        if (-not [guid]::TryParse($OperationId, [ref]$parsed)) {
            return [pscustomobject][ordered]@{ IsValid=$false; Request=$null; Errors=@([pscustomobject][ordered]@{ Code='OperationIdInvalid'; Message='OperationId must be a valid GUID.' }) }
        }
        $parsed.ToString()
    }

    [pscustomobject][ordered]@{
        IsValid = $true
        Request = [pscustomobject][ordered]@{
            OperationId = $resolvedOperationId
            DownloadOperationId = $DownloadResult.OperationId
            Manifest = $Manifest
            Installer = $Manifest.Installer
            Artifact = [pscustomobject][ordered]@{ Uri=$DownloadResult.Uri; FileName=$DownloadResult.FileName; Path=$DownloadResult.DestinationPath }
        }
        Errors = @()
    }
}
