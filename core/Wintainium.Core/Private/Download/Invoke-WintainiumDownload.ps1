function Test-WintainiumHtmlArtifactPayload {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $buffer = [byte[]]::new(1024)
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $read = $stream.Read($buffer, 0, $buffer.Length)
        if ($read -le 0) { return $false }
        $prefix = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read)
        $prefix = $prefix.TrimStart([char]0xFEFF, [char]0x20, [char]0x09, [char]0x0D, [char]0x0A)
        return $prefix -match '(?i)^(?:<!doctype\s+html\b|<html\b|<head\b|<body\b)'
    }
    catch { return $false }
    finally { if ($null -ne $stream) { $stream.Dispose() } }
}

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
    $artifactDirectory = if ($target.PSObject.Properties['ArtifactDirectory']) { [string]$target.ArtifactDirectory } else { $root }
    $operationId = if ($DownloadRequest.PSObject.Properties['OperationId']) { [string]$DownloadRequest.OperationId } else { $null }
    [System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
    if (Test-Path -LiteralPath $target.DestinationPath) {
        return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='DestinationExists'; Uri=$target.Uri; FileName=$target.FileName; ArtifactDirectory=$artifactDirectory; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$false; ErrorMessage='The destination file already exists.' }
    }
    $temporaryPath = Join-Path $artifactDirectory ([System.IO.Path]::GetRandomFileName())
    $ownsClient = $null -eq $HttpClient
    $requestMessage = $null
    if ($ownsClient) { [void]($HttpClient = [System.Net.Http.HttpClient]::new()) }
    try {
        try {
            $requestMessage = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $target.Uri)
            if ($target.PSObject.Properties['ReferrerUri'] -and -not [string]::IsNullOrWhiteSpace([string]$target.ReferrerUri)) {
                $referrer = $null
                if ([System.Uri]::TryCreate([string]$target.ReferrerUri, [System.UriKind]::Absolute, [ref]$referrer) -and $referrer.Scheme -eq 'https') {
                    $requestMessage.Headers.Referrer = $referrer
                }
            }
            [void]($response = $HttpClient.SendAsync($requestMessage, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead, $CancellationToken).GetAwaiter().GetResult())
        }
        catch [System.OperationCanceledException] { return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='Cancelled'; Uri=$target.Uri; FileName=$target.FileName; ArtifactDirectory=$artifactDirectory; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$false; ErrorMessage='The download was cancelled.' } }
        catch { return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='Network'; Uri=$target.Uri; FileName=$target.FileName; ArtifactDirectory=$artifactDirectory; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$true; ErrorMessage=$_.Exception.Message } }
        try {
            if (-not $response.IsSuccessStatusCode) {
                $retryable = [int]$response.StatusCode -ge 500 -or [int]$response.StatusCode -eq 408 -or [int]$response.StatusCode -eq 429
                return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='Http'; Uri=$target.Uri; FileName=$target.FileName; ArtifactDirectory=$artifactDirectory; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$retryable; ErrorMessage="HTTP status $([int]$response.StatusCode) ($($response.ReasonPhrase))." }
            }
            $contentType = $null
            if ($null -ne $response.Content -and $null -ne $response.Content.Headers.ContentType) {
                $contentType = [string]$response.Content.Headers.ContentType.MediaType
            }
            $finalUri = [string]$target.Uri
            try {
                if ($null -ne $response.RequestMessage -and $null -ne $response.RequestMessage.RequestUri) {
                    $finalUri = ([System.Uri]$response.RequestMessage.RequestUri).GetLeftPart([System.UriPartial]::Path)
                }
            } catch {}
            $isPackageArtifact = [System.IO.Path]::GetExtension([string]$target.FileName).ToLowerInvariant() -in @('.exe', '.msi', '.zip')
            if ($isPackageArtifact -and $contentType -in @('text/html', 'application/xhtml+xml')) {
                return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='UnexpectedContentType'; Uri=$target.Uri; FileName=$target.FileName; ArtifactDirectory=$artifactDirectory; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$false; ErrorMessage="The server returned HTML (Content-Type '$contentType') instead of the requested package. Final URL: '$finalUri'. The response was not saved as an artifact." }
            }
            try {
                [void]($stream = $response.Content.ReadAsStreamAsync($CancellationToken).GetAwaiter().GetResult())
                try {
                    [void]($fileStream = [System.IO.File]::Open($temporaryPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None))
                    try { [void]$stream.CopyToAsync($fileStream, $CancellationToken).GetAwaiter().GetResult() }
                    finally { [void]$fileStream.Dispose() }
                } finally { [void]$stream.Dispose() }
            }
            catch [System.OperationCanceledException] { return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='Cancelled'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=if (Test-Path -LiteralPath $temporaryPath) { [System.IO.FileInfo]::new($temporaryPath).Length } else { 0 }; Retryable=$false; ErrorMessage='The download was cancelled.' } }
            catch { return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='Transfer'; Uri=$target.Uri; FileName=$target.FileName; ArtifactDirectory=$artifactDirectory; DestinationPath=$target.DestinationPath; BytesWritten=if (Test-Path -LiteralPath $temporaryPath) { [System.IO.FileInfo]::new($temporaryPath).Length } else { 0 }; Retryable=$true; ErrorMessage=$_.Exception.Message } }
        } finally { [void]$response.Dispose() }
        $isPackageArtifact = [System.IO.Path]::GetExtension([string]$target.FileName).ToLowerInvariant() -in @('.exe', '.msi', '.zip')
        if ($isPackageArtifact -and (Test-WintainiumHtmlArtifactPayload -Path $temporaryPath)) {
            $bytesWritten = [System.IO.FileInfo]::new($temporaryPath).Length
            return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='InvalidArtifactPayload'; Uri=$target.Uri; FileName=$target.FileName; ArtifactDirectory=$artifactDirectory; DestinationPath=$target.DestinationPath; BytesWritten=$bytesWritten; Retryable=$false; ErrorMessage="The downloaded bytes are an HTML document, not a package. Final URL: '$finalUri'. The response was not published as an artifact." }
        }
        try { [void][System.IO.File]::Move($temporaryPath, $target.DestinationPath) }
        catch {
            if (Test-Path -LiteralPath $target.DestinationPath) { return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='DestinationExists'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$false; ErrorMessage='The destination file already exists.' } }
            return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Failed'; FailureKind='DestinationWrite'; Uri=$target.Uri; FileName=$target.FileName; DestinationPath=$target.DestinationPath; BytesWritten=0; Retryable=$true; ErrorMessage=$_.Exception.Message }
        }
        return [pscustomobject][ordered]@{ OperationId=$operationId; Status='Downloaded'; FailureKind=$null; Uri=$target.Uri; FileName=$target.FileName; ArtifactDirectory=$artifactDirectory; DestinationPath=$target.DestinationPath; BytesWritten=[System.IO.FileInfo]::new($target.DestinationPath).Length; Retryable=$false; ErrorMessage=$null }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) { [void](Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue) }
        if ($null -ne $requestMessage) { [void]$requestMessage.Dispose() }
        if ($ownsClient) { [void]$HttpClient.Dispose() }
    }
}