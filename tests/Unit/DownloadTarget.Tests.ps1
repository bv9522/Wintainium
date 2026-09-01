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
        $result = InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
            param($Request, $Root)
            Resolve-WintainiumDownloadTarget -DownloadRequest $Request -DownloadRoot $Root
        }
        $result.Uri | Should -Be 'https://example.com/releases/Wintainium-1.2.3-x64.zip'
        $result.FileName | Should -Be 'Wintainium-1.2.3-x64.zip'
        $result.DestinationPath | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $root 'Wintainium-1.2.3-x64.zip')))
    }

    It 'rejects non-HTTPS URIs' {
        $request.SelectedArtifact.Uri = 'http://example.com/file.zip'
        { InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
                param($Request, $Root)
                Resolve-WintainiumDownloadTarget -DownloadRequest $Request -DownloadRoot $Root
            } } | Should -Throw '*HTTPS is required*'
    }

    It 'rejects unsupported URI schemes' {
        $request.SelectedArtifact.Uri = 'file:///C:/Windows/System32/example.exe'
        { InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
                param($Request, $Root)
                Resolve-WintainiumDownloadTarget -DownloadRequest $Request -DownloadRoot $Root
            } } | Should -Throw '*not supported*'
    }

    It 'rejects path components in provider-supplied filenames' {
        $request.SelectedArtifact.FileName = '..\outside.exe'
        { InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
                param($Request, $Root)
                Resolve-WintainiumDownloadTarget -DownloadRequest $Request -DownloadRoot $Root
            } } | Should -Throw '*path components*'
    }

    It 'rejects reserved Windows device names' {
        $request.SelectedArtifact.FileName = 'CON.exe'
        { InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
                param($Request, $Root)
                Resolve-WintainiumDownloadTarget -DownloadRequest $Request -DownloadRoot $Root
            } } | Should -Throw '*reserved Windows device name*'
    }

    It 'derives a filename from the URI when the artifact filename is absent' {
        $request.SelectedArtifact.PSObject.Properties.Remove('FileName')
        $result = InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
            param($Request, $Root)
            Resolve-WintainiumDownloadTarget -DownloadRequest $Request -DownloadRoot $Root
        }
        $result.FileName | Should -Be 'Wintainium-1.2.3-x64.zip'
    }

    It 'rejects HTTPS URIs without a host' {
        $request.SelectedArtifact.Uri = 'https:///file.zip'
        { InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
                param($Request, $Root)
                Resolve-WintainiumDownloadTarget -DownloadRequest $Request -DownloadRoot $Root
            } } | Should -Throw '*absolute URI*'
    }

    It 'rejects HTTPS URIs containing user information' {
        $request.SelectedArtifact.Uri = 'https://user:password@example.com/file.zip'
        { InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
                param($Request, $Root)
                Resolve-WintainiumDownloadTarget -DownloadRequest $Request -DownloadRoot $Root
            } } | Should -Throw '*user information*'
    }

    It 'rejects URI fragments' {
        $request.SelectedArtifact.Uri = 'https://example.com/file.zip#download'
        { InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
                param($Request, $Root)
                Resolve-WintainiumDownloadTarget -DownloadRequest $Request -DownloadRoot $Root
            } } | Should -Throw '*fragment*'
    }

    It 'rejects filenames ending with a space or period' {
        $request.SelectedArtifact.FileName = 'artifact.zip '
        { InModuleScope Wintainium.Core -Parameters @{ Request = $request; Root = $root } {
                param($Request, $Root)
                Resolve-WintainiumDownloadTarget -DownloadRequest $Request -DownloadRoot $Root
            } } | Should -Throw '*end with a space or period*'
    }
}
