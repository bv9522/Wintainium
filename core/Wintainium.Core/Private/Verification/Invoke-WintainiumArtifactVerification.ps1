function Invoke-WintainiumArtifactVerification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$DownloadResult,
        [Parameter(Mandatory)] [psobject]$SelectedArtifact,
        [string]$OperationId
    )

    $resolvedOperationId = if ($PSBoundParameters.ContainsKey('OperationId')) { $OperationId } elseif ($null -ne $DownloadResult -and $DownloadResult.PSObject.Properties['OperationId']) { [string]$DownloadResult.OperationId } else { $null }
    $destinationPath = if ($null -ne $DownloadResult -and $DownloadResult.PSObject.Properties['DestinationPath']) { [string]$DownloadResult.DestinationPath } else { $null }
    $failed = {
        param([string]$Kind,[string]$Message)
        [pscustomobject][ordered]@{ OperationId=$resolvedOperationId; Status='Failed'; FailureKind=$Kind; Algorithm=$null; ExpectedHash=$null; ActualHash=$null; DestinationPath=$destinationPath; ErrorMessage=$Message }
    }

    if ($null -eq $DownloadResult -or $null -eq $SelectedArtifact) { return & $failed 'InputInvalid' 'DownloadResult and SelectedArtifact are required.' }
    if (-not $DownloadResult.PSObject.Properties['Status']) { return & $failed 'InputInvalid' 'DownloadResult is missing Status.' }
    if ([string]$DownloadResult.Status -ne 'Downloaded') { return & $failed 'DownloadNotCompleted' 'Artifact verification requires a completed download.' }
    if ([string]::IsNullOrWhiteSpace($destinationPath)) { return & $failed 'DestinationMissing' 'The download result does not contain a destination path.' }
    if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) { return & $failed 'DestinationMissing' 'The downloaded artifact does not exist as a regular file.' }
    if (-not $SelectedArtifact.PSObject.Properties['Hashes'] -or $null -eq $SelectedArtifact.Hashes) { return & $failed 'VerificationMetadataMissing' 'The selected artifact contains no verification hash evidence.' }

    $claims = [System.Collections.Generic.List[object]]::new()
    $hashes = $SelectedArtifact.Hashes
    if ($hashes -is [System.Collections.IDictionary]) {
        foreach ($key in $hashes.Keys) { $claims.Add([pscustomobject]@{ Algorithm=[string]$key; Value=[string]$hashes[$key] }) }
    } else {
        foreach ($claim in @($hashes)) {
            if ($null -ne $claim -and $claim.PSObject.Properties['Algorithm'] -and $claim.PSObject.Properties['Value']) {
                $claims.Add([pscustomobject]@{ Algorithm=[string]$claim.Algorithm; Value=[string]$claim.Value })
            } else {
                return & $failed 'VerificationMetadataInvalid' 'A hash claim is missing Algorithm or Value.'
            }
        }
    }

    $sha256Claims = @($claims | Where-Object { $_.Algorithm -ieq 'SHA256' })
    if ($claims.Count -gt 0 -and $sha256Claims.Count -eq 0) { return & $failed 'UnsupportedVerificationAlgorithm' 'The artifact declares no supported SHA256 verification evidence.' }
    if ($sha256Claims.Count -eq 0) { return & $failed 'VerificationMetadataMissing' 'The selected artifact contains no SHA256 verification evidence.' }

    foreach ($claim in $sha256Claims) {
        if ([string]::IsNullOrWhiteSpace($claim.Value) -or $claim.Value -notmatch '^[0-9A-Fa-f]{64}$') { return & $failed 'VerificationMetadataInvalid' 'A SHA256 verification value is not a valid 64-character hexadecimal digest.' }
    }

    try { $actualHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant() }
    catch { return & $failed 'VerificationFailed' 'The downloaded artifact could not be hashed for verification.' }

    foreach ($claim in $sha256Claims) {
        if ($actualHash -cne $claim.Value.ToUpperInvariant()) {
            return [pscustomobject][ordered]@{ OperationId=$resolvedOperationId; Status='Failed'; FailureKind='HashMismatch'; Algorithm='SHA256'; ExpectedHash=$claim.Value.ToUpperInvariant(); ActualHash=$actualHash; DestinationPath=$destinationPath; ErrorMessage='The downloaded artifact hash does not match the declared SHA256 verification evidence.' }
        }
    }

    [pscustomobject][ordered]@{ OperationId=$resolvedOperationId; Status='Verified'; FailureKind=$null; Algorithm='SHA256'; ExpectedHash=$sha256Claims[0].Value.ToUpperInvariant(); ActualHash=$actualHash; DestinationPath=$destinationPath; ErrorMessage=$null }
}
