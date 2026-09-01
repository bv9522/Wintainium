$modulePath = Join-Path $PSScriptRoot '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
Import-Module $modulePath -Force

if (-not ([System.Management.Automation.PSTypeName]'Wintainium.Tests.ResultHandoffHttpHandler').Type) {
    Add-Type -TypeDefinition @'
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace Wintainium.Tests
{
    public sealed class ResultHandoffHttpHandler : HttpMessageHandler
    {
        public HttpResponseMessage Response { get; }

        public ResultHandoffHttpHandler(HttpResponseMessage response)
        {
            Response = response;
        }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Response);
        }
    }
}
'@
}

Describe 'Phase 5 download result handoff' {
    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $artifact = [pscustomobject]@{ Uri='https://example.com/releases/Wintainium-1.2.3-x64.zip'; FileName='Wintainium-1.2.3-x64.zip' }
        $request = [pscustomobject]@{ SelectedArtifact=$artifact }
    }

    It 'returns a stable success result containing the completed local artifact location' {
        $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::OK)
        $response.Content = [System.Net.Http.ByteArrayContent]::new([System.Text.Encoding]::UTF8.GetBytes('artifact bytes'))
        $handler = [Wintainium.Tests.ResultHandoffHttpHandler]::new($response)
        $client = [System.Net.Http.HttpClient]::new($handler)
        try {
            $result = InModuleScope Wintainium.Core -Parameters @{ Request=$request; Root=$root; Client=$client } {
                param($Request,$Root,$Client)
                Mock Resolve-WintainiumDownloadTarget {
                    [pscustomobject]@{ Uri=$Request.SelectedArtifact.Uri; DownloadRoot=$Root; FileName=$Request.SelectedArtifact.FileName; DestinationPath=Join-Path $Root $Request.SelectedArtifact.FileName }
                }
                Invoke-WintainiumDownload -DownloadRequest $Request -DownloadRoot $Root -HttpClient $Client
            }

            $result.PSObject.Properties.Name | Should -Contain 'Status'
            $result.PSObject.Properties.Name | Should -Contain 'FailureKind'
            $result.PSObject.Properties.Name | Should -Contain 'Uri'
            $result.PSObject.Properties.Name | Should -Contain 'FileName'
            $result.PSObject.Properties.Name | Should -Contain 'DestinationPath'
            $result.PSObject.Properties.Name | Should -Contain 'BytesWritten'
            $result.PSObject.Properties.Name | Should -Contain 'Retryable'
            $result.PSObject.Properties.Name | Should -Contain 'ErrorMessage'
            $result.Status | Should -Be 'Downloaded'
            $result.FailureKind | Should -BeNullOrEmpty
            $result.Uri | Should -Be $artifact.Uri
            $result.FileName | Should -Be $artifact.FileName
            $result.DestinationPath | Should -Be (Join-Path $root $artifact.FileName)
            $result.BytesWritten | Should -Be ([System.Text.Encoding]::UTF8.GetByteCount('artifact bytes'))
            $result.Retryable | Should -BeFalse
            $result.ErrorMessage | Should -BeNullOrEmpty
            Test-Path -LiteralPath $result.DestinationPath | Should -BeTrue
        }
        finally { $client.Dispose(); $response.Dispose() }
    }

    It 'returns a structured failure result without claiming a local artifact was produced' {
        $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::ServiceUnavailable)
        $handler = [Wintainium.Tests.ResultHandoffHttpHandler]::new($response)
        $client = [System.Net.Http.HttpClient]::new($handler)
        try {
            $result = InModuleScope Wintainium.Core -Parameters @{ Request=$request; Root=$root; Client=$client } {
                param($Request,$Root,$Client)
                Mock Resolve-WintainiumDownloadTarget {
                    [pscustomobject]@{ Uri=$Request.SelectedArtifact.Uri; DownloadRoot=$Root; FileName=$Request.SelectedArtifact.FileName; DestinationPath=Join-Path $Root $Request.SelectedArtifact.FileName }
                }
                Invoke-WintainiumDownload -DownloadRequest $Request -DownloadRoot $Root -HttpClient $Client
            }

            $result.Status | Should -Be 'Failed'
            $result.FailureKind | Should -Be 'Http'
            $result.Uri | Should -Be $artifact.Uri
            $result.FileName | Should -Be $artifact.FileName
            $result.DestinationPath | Should -Be (Join-Path $root $artifact.FileName)
            $result.BytesWritten | Should -Be 0
            $result.Retryable | Should -BeTrue
            $result.ErrorMessage | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath $result.DestinationPath | Should -BeFalse
        }
        finally { $client.Dispose(); $response.Dispose() }
    }

    It 'does not blur download completion into artifact trust or installation readiness' {
        $parameters = InModuleScope Wintainium.Core { (Get-Command Invoke-WintainiumDownload -CommandType Function).Parameters.Keys }
        $parameters | Should -Not -Contain 'Verify'
        $parameters | Should -Not -Contain 'Hash'
        $parameters | Should -Not -Contain 'Signature'
        $parameters | Should -Not -Contain 'Installer'
        $parameters | Should -Not -Contain 'Execute'
    }
}
