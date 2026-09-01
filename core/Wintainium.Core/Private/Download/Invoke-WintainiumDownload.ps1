function Invoke-WintainiumDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$DownloadRequest,
        [Parameter(Mandatory)]
        [string]$DownloadRoot,
        [Parameter()]
        [System.Net.Http.HttpClient]$HttpClient,
        [Parameter()]
        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
    )

    $target = Resolve-WintainiumDownloadTarget -DownloadRequest $DownloadRequest -DownloadRoot $DownloadRoot
    $root = $target.DownloadRoot
    $operationId = if ($DownloadRequest.PSObject.Properties['OperationId']) { [string]$DownloadRequest.OperationId } else { $null }
    [System.IO.Directory]::CreateDirectory($root) | Out-Null
    if (Test-Path -LiteralPath $target.DestinationPath) {
        return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='DestinationExists'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$false; ErrorMessage='The destination file already exists.' }
    }
    $temporaryPath = Join-Path $root ([System.IO.Path]::GetRandomFileName())
    $ownsClient = $null -eq $HttpClient
    if ($ownsClient) { $HttpClient = [System.Net.Http.HttpClient]::new() }
    try {
        try { $response = $HttpClient.GetAsync($target.Uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead, $CancellationToken).GetAwaiter().GetResult() }
        catch [System.OperationCanceledException] { return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='Cancelled'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$false; ErrorMessage='The download was cancelled.' } }
        catch { return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='Network'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$true; ErrorMessage=$_.Exception.Message } }
        try {
            if (-not $response.IsSuccessStatusCode) {
                $retryable = [int]$response.StatusCode -ge 500 -or [int]$response.StatusCode -eq 408 -or [int]$response.StatusCode -eq 429
                return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='Http'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$retryable; ErrorMessage="HTTP status $([int]$response.StatusCode) ($($response.ReasonPhrase))." }
            }
            try {
                $stream = $response.Content.ReadAsStreamAsync($CancellationToken).GetAwaiter().GetResult()
                try {
                    $fileStream = [System.IO.File]::Open($temporaryPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                    try { $stream.CopyToAsync($fileStream, $CancellationToken).GetAwaiter().GetResult() }
                    finally { $fileStream.Dispose() }
                } finally { $stream.Dispose() }
            }
            catch [System.OperationCanceledException] { return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='Cancelled'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=if (Test-Path -LiteralPath $temporaryPath) { [System.IO.FileInfo]::new($temporaryPath).Length } else { 0 }; Retryable=$false; ErrorMessage='The download was cancelled.' } }
            catch { return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='Transfer'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=if (Test-Path -LiteralPath $temporaryPath) { [System.IO.FileInfo]::new($temporaryPath).Length } else { 0 }; Retryable=$true; ErrorMessage=$_.Exception.Message } }
        } finally { $response.Dispose() }
        try { [System.IO.File]::Move($temporaryPath, $target.DestinationPath) }
        catch {
            if (Test-Path -LiteralPath $target.DestinationPath) { return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='DestinationExists'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$false; ErrorMessage='The destination file already exists.' } }
            return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='DestinationWrite'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$true; ErrorMessage=$_.Exception.Message }
        }
        [pscustomobject][ordered]@{ OperationId=$operationId; Status='Downloaded'; FailureKind=$null; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=[System.IO.FileInfo]::new($target.DestinationPath).Length; Retryable=$false; ErrorMessage=$null }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue }
        if ($ownsClient) { $HttpClient.Dispose() }
    }
}
