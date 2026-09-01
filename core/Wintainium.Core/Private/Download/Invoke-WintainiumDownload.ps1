function Invoke-WintainiumDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$DownloadRequest,
        [Parameter(Mandatory)]
        [string]$DownloadRoot,
        [Parameter()]
        [System.Net.Http.HttpClient]$HttpClient
    )

    $target = Resolve-WintainiumDownloadTarget -DownloadRequest $DownloadRequest -DownloadRoot $DownloadRoot
    $root = $target.DownloadRoot
    [System.IO.Directory]::CreateDirectory($root) | Out-Null
    if (Test-Path -LiteralPath $target.DestinationPath) {
        return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='DestinationExists'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$false; ErrorMessage='The destination file already exists.' }
    }
    $temporaryPath = Join-Path $root ([System.IO.Path]::GetRandomFileName())
    $ownsClient = $null -eq $HttpClient
    if ($ownsClient) { $HttpClient = [System.Net.Http.HttpClient]::new() }
    try {
        try { $response = $HttpClient.GetAsync($target.Uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult() }
        catch { return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='Network'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$true; ErrorMessage=$_.Exception.Message } }
        try {
            if (-not $response.IsSuccessStatusCode) {
                $retryable = [int]$response.StatusCode -ge 500 -or [int]$response.StatusCode -eq 408 -or [int]$response.StatusCode -eq 429
                return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='Http'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$retryable; ErrorMessage="HTTP status $([int]$response.StatusCode) ($($response.ReasonPhrase))." }
            }
            try {
                $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                try {
                    $fileStream = [System.IO.File]::Open($temporaryPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                    try { $stream.CopyToAsync($fileStream).GetAwaiter().GetResult() }
                    finally { $fileStream.Dispose() }
                } finally { $stream.Dispose() }
            }
            catch { return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='Transfer'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=if (Test-Path -LiteralPath $temporaryPath) { [System.IO.FileInfo]::new($temporaryPath).Length } else { 0 }; Retryable=$true; ErrorMessage=$_.Exception.Message } }
        } finally { $response.Dispose() }
        try { [System.IO.File]::Move($temporaryPath, $target.DestinationPath) }
        catch {
            if (Test-Path -LiteralPath $target.DestinationPath) { return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='DestinationExists'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$false; ErrorMessage='The destination file already exists.' } }
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='DestinationWrite'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$true; ErrorMessage=$_.Exception.Message }
        }
        [pscustomobject][ordered]@{ Status='Downloaded'; FailureKind=$null; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=[System.IO.FileInfo]::new($target.DestinationPath).Length; Retryable=$false; ErrorMessage=$null }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue }
        if ($ownsClient) { $HttpClient.Dispose() }
    }
}
