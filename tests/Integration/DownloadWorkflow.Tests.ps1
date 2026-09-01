BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force

    if (-not ([System.Management.Automation.PSTypeName]'Wintainium.Tests.WorkflowHttpHandler').Type) {
        Add-Type -TypeDefinition @'
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace Wintainium.Tests
{
    public sealed class WorkflowHttpHandler : HttpMessageHandler
    {
        public HttpResponseMessage Response { get; }

        public WorkflowHttpHandler(HttpResponseMessage response)
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
}

Describe 'Core download workflow' {
    It 'carries the selected Phase 4 artifact into a completed Phase 5 handoff' {
        $decision = [pscustomobject]@{
            Status = 'UpdateAvailable'
            IsUpdateAvailable = $true
            SelectedRelease = [pscustomobject]@{ ReleaseId = 'fixture-release-1'; Version = '1.2.3' }
            SelectedArtifact = [pscustomobject]@{
                Uri = 'https://example.invalid/example-1.2.3-x64.zip'
                FileName = 'example-1.2.3-x64.zip'
                Format = 'zip'
                Architecture = 'x64'
            }
        }

        $request = InModuleScope Wintainium.Core -Parameters @{ Decision = $decision } {
            param($Decision)
            New-WintainiumDownloadRequest -UpdateDecision $Decision
        }

        $root = Join-Path $TestDrive 'downloads'
        $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::OK)
        $response.Content = [System.Net.Http.ByteArrayContent]::new([System.Text.Encoding]::UTF8.GetBytes('fixture artifact'))
        $handler = [Wintainium.Tests.WorkflowHttpHandler]::new($response)
        $client = [System.Net.Http.HttpClient]::new($handler)
        try {
            $result = InModuleScope Wintainium.Core -Parameters @{ Request=$request; Root=$root; Client=$client } {
                param($Request,$Root,$Client)
                Mock Resolve-WintainiumDownloadTarget {
                    [pscustomobject]@{
                        Uri = $Request.SelectedArtifact.Uri
                        DownloadRoot = $Root
                        FileName = $Request.SelectedArtifact.FileName
                        DestinationPath = Join-Path $Root $Request.SelectedArtifact.FileName
                    }
                }
                Invoke-WintainiumDownload -DownloadRequest $Request -DownloadRoot $Root -HttpClient $Client
            }

            $result.OperationId | Should -Be $request.OperationId
            $result.Status | Should -Be 'Downloaded'
            $result.Uri | Should -Be $request.SelectedArtifact.Uri
            $result.FileName | Should -Be $request.SelectedArtifact.FileName
            Test-Path -LiteralPath $result.DestinationPath | Should -BeTrue
            [System.IO.File]::ReadAllText($result.DestinationPath) | Should -Be 'fixture artifact'
        }
        finally {
            $client.Dispose()
            $response.Dispose()
        }
    }
}
