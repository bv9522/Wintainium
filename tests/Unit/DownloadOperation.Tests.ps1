$modulePath = Join-Path $PSScriptRoot '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
Import-Module $modulePath -Force

class TestDownloadHandler : System.Net.Http.HttpMessageHandler {
    [System.Net.Http.HttpResponseMessage] $Response
    TestDownloadHandler([System.Net.Http.HttpResponseMessage] $response) { $this.Response = $response }
    [System.Threading.Tasks.Task[System.Net.Http.HttpResponseMessage]] SendAsync([System.Net.Http.HttpRequestMessage] $request, [System.Threading.CancellationToken] $cancellationToken) { return [System.Threading.Tasks.Task[System.Net.Http.HttpResponseMessage]]::FromResult($this.Response) }
}

Describe 'Invoke-WintainiumDownload' {
    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $artifact = [pscustomobject]@{ Uri='https://example.com/releases/Wintainium-1.2.3-x64.zip'; FileName='Wintainium-1.2.3-x64.zip' }
        $request = [pscustomobject]@{ SelectedArtifact=$artifact }
    }
    It 'exposes the controlled download operation through the Core module boundary' { InModuleScope Wintainium.Core { Get-Command Invoke-WintainiumDownload -CommandType Function } | Should -Not -BeNullOrEmpty }
    It 'rejects an unsafe target before attempting network I/O' { $request.SelectedArtifact.Uri='http://example.com/file.zip'; { InModuleScope Wintainium.Core -Parameters @{Request=$request;Root=$root} { param($Request,$Root); Invoke-WintainiumDownload -DownloadRequest $Request -DownloadRoot $Root } } | Should -Throw '*HTTPS is required*' }
    It 'does not expose installer or execution parameters at the download boundary' { $parameters=InModuleScope Wintainium.Core { (Get-Command Invoke-WintainiumDownload -CommandType Function).Parameters.Keys }; $parameters | Should -Not -Contain 'Installer'; $parameters | Should -Not -Contain 'Execute' }
    It 'downloads bytes and atomically completes the destination file' {
        $response=[System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::OK); $response.Content=[System.Net.Http.ByteArrayContent]::new([System.Text.Encoding]::UTF8.GetBytes('Wintainium test artifact')); $handler=[TestDownloadHandler]::new($response); $client=[System.Net.Http.HttpClient]::new($handler)
        try { $result=InModuleScope Wintainium.Core -Parameters @{Request=$request;Root=$root;Client=$client} { param($Request,$Root,$Client); Mock Resolve-WintainiumDownloadTarget { [pscustomobject]@{Uri=$Request.SelectedArtifact.Uri;DownloadRoot=$Root;FileName=$Request.SelectedArtifact.FileName;DestinationPath=Join-Path $Root $Request.SelectedArtifact.FileName} }; Invoke-WintainiumDownload -DownloadRequest $Request -DownloadRoot $Root -HttpClient $Client }; $result.Status|Should -Be 'Downloaded'; $result.FailureKind|Should -BeNullOrEmpty; $result.Retryable|Should -BeFalse; $result.BytesWritten|Should -Be ([System.Text.Encoding]::UTF8.GetByteCount('Wintainium test artifact')); Test-Path -LiteralPath $result.DestinationPath|Should -BeTrue; [System.IO.File]::ReadAllText($result.DestinationPath)|Should -Be 'Wintainium test artifact'; Get-ChildItem -LiteralPath $root -File | Where-Object Name -ne $request.SelectedArtifact.FileName | Should -BeNullOrEmpty } finally { $client.Dispose(); $response.Dispose() }
    }
    It 'returns a retryable HTTP failure without creating a destination file' {
        $response=[System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::ServiceUnavailable); $response.ReasonPhrase='Unavailable'; $handler=[TestDownloadHandler]::new($response); $client=[System.Net.Http.HttpClient]::new($handler)
        try { $result=InModuleScope Wintainium.Core -Parameters @{Request=$request;Root=$root;Client=$client} { param($Request,$Root,$Client); Mock Resolve-WintainiumDownloadTarget { [pscustomobject]@{Uri=$Request.SelectedArtifact.Uri;DownloadRoot=$Root;FileName=$Request.SelectedArtifact.FileName;DestinationPath=Join-Path $Root $Request.SelectedArtifact.FileName} }; Invoke-WintainiumDownload -DownloadRequest $Request -DownloadRoot $Root -HttpClient $Client }; $result.Status|Should -Be 'Failed'; $result.FailureKind|Should -Be 'Http'; $result.Retryable|Should -BeTrue; Test-Path -LiteralPath (Join-Path $root $request.SelectedArtifact.FileName)|Should -BeFalse; Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Should -BeNullOrEmpty } finally { $client.Dispose(); $response.Dispose() }
    }
    It 'returns a non-retryable destination collision and preserves the existing file' {
        [System.IO.Directory]::CreateDirectory($root)|Out-Null; $destination=Join-Path $root $request.SelectedArtifact.FileName; [System.IO.File]::WriteAllText($destination,'existing artifact'); $response=[System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::OK); $response.Content=[System.Net.Http.ByteArrayContent]::new([System.Text.Encoding]::UTF8.GetBytes('new artifact')); $handler=[TestDownloadHandler]::new($response); $client=[System.Net.Http.HttpClient]::new($handler)
        try { $result=InModuleScope Wintainium.Core -Parameters @{Request=$request;Root=$root;Client=$client} { param($Request,$Root,$Client); Mock Resolve-WintainiumDownloadTarget { [pscustomobject]@{Uri=$Request.SelectedArtifact.Uri;DownloadRoot=$Root;FileName=$Request.SelectedArtifact.FileName;DestinationPath=Join-Path $Root $Request.SelectedArtifact.FileName} }; Invoke-WintainiumDownload -DownloadRequest $Request -DownloadRoot $Root -HttpClient $Client }; $result.Status|Should -Be 'Failed'; $result.FailureKind|Should -Be 'DestinationExists'; $result.Retryable|Should -BeFalse; [System.IO.File]::ReadAllText($destination)|Should -Be 'existing artifact'; Get-ChildItem -LiteralPath $root -File | Where-Object Name -ne $request.SelectedArtifact.FileName | Should -BeNullOrEmpty } finally { $client.Dispose(); $response.Dispose() }
    }
}
