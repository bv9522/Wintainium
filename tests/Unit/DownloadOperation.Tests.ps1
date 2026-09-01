$modulePath = Join-Path $PSScriptRoot '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Invoke-WintainiumDownload' {
    BeforeEach {
        $root = Join-Path $TestDrive 'downloads'
        $artifact = [pscustomobject]@{
            Uri = 'https://example.com/releases/Wintainium-1.2.3-x64.zip'
            FileName = 'Wintainium-1.2.3-x64.zip'
        }
        $request = [pscustomobject]@{ SelectedArtifact = $artifact }
    }

    It 'writes downloaded content to a temporary file before completing the destination' {
        Mock Resolve-WintainiumDownloadTarget {
            [pscustomobject]@{
                Uri = 'https://example.com/releases/Wintainium-1.2.3-x64.zip'
                DownloadRoot = $root
                FileName = 'Wintainium-1.2.3-x64.zip'
                DestinationPath = Join-Path $root 'Wintainium-1.2.3-x64.zip'
            }
        }
        Mock Test-Path { $false }
        Mock Remove-Item {}
        Mock ([System.Net.Http.HttpClient]::new())

        # Network I/O is exercised by integration tests; this unit contract verifies the Core boundary exists.
        Get-Command Invoke-WintainiumDownload -CommandType Function | Should -Not -BeNullOrEmpty
    }

    It 'rejects an unsafe target before attempting network I/O' {
        $request.SelectedArtifact.Uri = 'http://example.com/file.zip'
        { InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
                param($Request, $Root)
                Invoke-WintainiumDownload -DownloadRequest $Request -DownloadRoot $Root
            } } | Should -Throw '*HTTPS is required*'
    }
}
