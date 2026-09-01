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

    It 'exposes the controlled download operation through the Core module boundary' {
        $command = InModuleScope Wintainium.Core {
            Get-Command Invoke-WintainiumDownload -CommandType Function
        }
        $command | Should -Not -BeNullOrEmpty
    }

    It 'rejects an unsafe target before attempting network I/O' {
        $request.SelectedArtifact.Uri = 'http://example.com/file.zip'
        { InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
                param($Request, $Root)
                Invoke-WintainiumDownload -DownloadRequest $Request -DownloadRoot $Root
            } } | Should -Throw '*HTTPS is required*'
    }

    It 'does not expose installer or execution parameters at the download boundary' {
        $parameters = InModuleScope Wintainium.Core {
            (Get-Command Invoke-WintainiumDownload -CommandType Function).Parameters.Keys
        }
        $parameters | Should -Not -Contain 'Installer'
        $parameters | Should -Not -Contain 'Execute'
    }
}
