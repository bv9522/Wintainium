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
    $temporaryPath = Join-Path $root ([System.IO.Path]::GetRandomFileName())
    $ownsClient = $null -eq $HttpClient

    if ($ownsClient) {
        $HttpClient = [System.Net.Http.HttpClient]::new()
    }

    try {
        $response = $HttpClient.GetAsync($target.Uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        try {
            $response.EnsureSuccessStatusCode() | Out-Null
            $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            try {
                $fileStream = [System.IO.File]::Open($temporaryPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                try {
                    $stream.CopyToAsync($fileStream).GetAwaiter().GetResult()
                }
                finally {
                    $fileStream.Dispose()
                }
            }
            finally {
                $stream.Dispose()
            }
        }
        finally {
            $response.Dispose()
        }

        [System.IO.File]::Move($temporaryPath, $target.DestinationPath)

        [pscustomobject][ordered]@{
            Status = 'Downloaded'
            Uri = $target.Uri
            FileName = $target.FileName
            DestinationPath = $target.DestinationPath
            BytesWritten = [System.IO.FileInfo]::new($target.DestinationPath).Length
        }
    }
    catch {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
    finally {
        if ($ownsClient) {
            $HttpClient.Dispose()
        }
    }
}
