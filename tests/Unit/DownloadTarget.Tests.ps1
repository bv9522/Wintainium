$modulePath = Join-Path $PSScriptRoot '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Resolve-WintainiumDownloadTarget' {
    BeforeEach {
        $root = Join-Path $TestDrive 'downloads'
        $artifact = [pscustomobject]@{
            Uri = 'https://example.com/releases/Wintainium-1.2.3-x64.zip'
            FileName = 'Wintainium-1.2.3-x64.zip'
        }
        $request = [pscustomobject]@{ SelectedArtifact = $artifact }
    }

    It 'accepts an absolute HTTPS URI and resolves within the download root' {
        $result = Resolve-WintainiumDownloadTarget -DownloadRequest $request -DownloadRoot $root
        $result.Uri | Should -Be 'https://example.com/releases/Wintainium-1.2.3-x64.zip'
        $result.FileName | Should -Be 'Wintainium-1.2.3-x64.zip'
        $result.DestinationPath | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $root 'Wintainium-1.2.3-x64.zip')))
    }

    It 'rejects non-HTTPS URIs' {
        $request.SelectedArtifact.Uri = 'http://example.com/file.zip'
        { Resolve-WintainiumDownloadTarget -DownloadRequest $request -DownloadRoot $root } | Should -Throw '*HTTPS is required*'
    }

    It 'rejects unsupported URI schemes' {
        $request.SelectedArtifact.Uri = 'file:///C:/Windows/System32/example.exe'
        { Resolve-WintainiumDownloadTarget -DownloadRequest $request -DownloadRoot $root } | Should -Throw '*not supported*'
    }

    It 'rejects path components in provider-supplied filenames' {
        $request.SelectedArtifact.FileName = '..\outside.exe'
        { Resolve-WintainiumDownloadTarget -DownloadRequest $request -DownloadRoot $root } | Should -Throw '*path components*'
    }

    It 'rejects reserved Windows device names' {
        $request.SelectedArtifact.FileName = 'CON.exe'
        { Resolve-WintainiumDownloadTarget -DownloadRequest $request -DownloadRoot $root } | Should -Throw '*reserved Windows device name*'
    }

    It 'derives a filename from the URI when the artifact filename is absent' {
        $request.SelectedArtifact.PSObject.Properties.Remove('FileName')
        $result = Resolve-WintainiumDownloadTarget -DownloadRequest $request -DownloadRoot $root
        $result.FileName | Should -Be 'Wintainium-1.2.3-x64.zip'
    }
}
