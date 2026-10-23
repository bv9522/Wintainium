BeforeAll {
    $script:testRoot=Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:providerPath=Join-Path $script:testRoot 'plugins/Wintainium.provider.official-download-page/Wintainium.provider.official-download-page.psm1'
    Import-Module $script:providerPath -Force
    $script:response=[pscustomobject]@{
        Content='<html><head><title>7-Zip</title><meta name="application-name" content="7-Zip"><meta property="og:site_name" content="7-Zip"><link rel="canonical" href="https://www.7-zip.org/download.html"></head><body><h1>Download</h1><a href="/a/7z2501-x64.exe">Download</a></body></html>'
        Headers=@{'Content-Type'='text/html; charset=UTF-8'}
    }
}

Describe 'Wintainium official download page source resolution' {
    It 'resolves structured official HTML into normalized source facts' {
        Mock Invoke-WebRequest {$script:response} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {
            param($uri)
            Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-1';SourceUri=$uri})
        } 'https://www.7-zip.org/download.html'
        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Resolved'
        $result.OperationId | Should -Be 'page-test-1'
        $result.Source.Name | Should -Be '7-Zip'
        $result.Source.CanonicalUri | Should -Be 'https://www.7-zip.org/download.html'
        $result.Source.ProviderId | Should -Be 'Wintainium.provider.official-download-page'
        $result.Source.ProviderSettings.pageUri | Should -Be 'https://www.7-zip.org/download.html'
    }

    It 'accepts canonical link attributes in different attribute order' {
        Mock Invoke-WebRequest {[pscustomobject]@{Content='<html><head><title>7-Zip</title><link href="/download.html" rel="canonical"></head></html>';Headers=@{'Content-Type'='text/html'}}} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-canonical-order';SourceUri='https://www.7-zip.org/download.html'})}
        $result.IsSuccessful | Should -Be $true
        $result.Source.CanonicalUri | Should -Be 'https://www.7-zip.org/download.html'
    }

    It 'uses image alt text when the page heading is generic' {
        Mock Invoke-WebRequest {[pscustomobject]@{Content='<html><head><title>Download</title></head><body><img src="/logo.png" alt="7-Zip"><h1>Download</h1></body></html>';Headers=@{'Content-Type'='text/html'}}} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-alt';SourceUri='https://www.7-zip.org/download.html'})}
        $result.IsSuccessful | Should -Be $true
        $result.Source.Name | Should -Be '7-Zip'
    }

    It 'uses the title publisher suffix when explicit publisher metadata is absent' {
        Mock Invoke-WebRequest {[pscustomobject]@{Content='<html><head><title>Official download of VLC media player - VideoLAN</title></head><body><h1>VLC media player</h1></body></html>';Headers=@{'Content-Type'='text/html'}}} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-publisher';SourceUri='https://www.videolan.org/vlc/'})}
        $result.IsSuccessful | Should -Be $true
        $result.Source.Name | Should -Be 'VLC media player'
        $result.Source.Publisher | Should -Be 'VideoLAN'
    }

    It 'accepts supported metadata in different attribute order' {
        Mock Invoke-WebRequest {[pscustomobject]@{Content='<html><head><meta content="VideoLAN" property="og:site_name"><meta content="VLC media player" name="application-name"><title>VLC download</title></head></html>';Headers=@{'Content-Type'='text/html'}}} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-2';SourceUri='https://www.videolan.org/vlc/'})}
        $result.IsSuccessful | Should -Be $true
        $result.Source.Name | Should -Be 'VLC media player'
        $result.Source.Publisher | Should -Be 'VideoLAN'
    }

    It 'separates HandBrake product identity from its tagline and preserves a description' {
        Mock Invoke-WebRequest {[pscustomobject]@{Content='<html><head><meta name="application-name" content="Handbrake The open source video transcoder"><meta name="description" content="A video transcoder for multiple platforms."></head><body></body></html>';Headers=@{'Content-Type'='text/html'}}} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-handbrake';SourceUri='https://handbrake.fr/downloads.php'})}
        $result.IsSuccessful | Should -BeTrue
        $result.Source.Name | Should -Be 'HandBrake'
        $result.Source.Description | Should -Be 'A video transcoder for multiple platforms.'
    }

    It 'identifies the AMD driver landing page as AMD Software rather than the AMD vendor' {
        Mock Invoke-WebRequest {[pscustomobject]@{Content='<html><head><meta name="application-name" content="AMD Drivers and Support"><meta name="description" content="Drivers and software."></head></html>';Headers=@{'Content-Type'='text/html'}}} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-amd';SourceUri='https://www.amd.com/en/support/download/drivers.html'})}
        $result.IsSuccessful | Should -BeTrue
        $result.Source.Name | Should -Be 'AMD Software'
        $result.Source.Description | Should -Be 'Drivers and software.'
    }

    It 'removes the Files section label from SourceForge project-page names' {
        Mock Invoke-WebRequest {[pscustomobject]@{Content='<html><head><title>Equalizer APO Files - SourceForge</title><meta name="application-name" content="Equalizer APO Files - SourceForge"></head><body></body></html>';Headers=@{'Content-Type'='text/html'}}} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-equalizerapo';SourceUri='https://sourceforge.net/projects/equalizerapo/files/1.4.2/'})}
        $result.IsSuccessful | Should -BeTrue
        $result.Source.Name | Should -Be 'Equalizer APO'
    }

    It 'removes the Download page label from the official Equalizer APO download page' {
        Mock Invoke-WebRequest {[pscustomobject]@{Content='<html><head><title>Equalizer APO Download</title><meta name="application-name" content="Equalizer APO Download"></head><body></body></html>';Headers=@{'Content-Type'='text/html'}}} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-equalizerapo-official';SourceUri='https://equalizerapo.com/download'})}
        $result.IsSuccessful | Should -BeTrue
        $result.Source.Name | Should -Be 'Equalizer APO'
    }

    It 'does not return download artifacts during source resolution' {
        Mock Invoke-WebRequest {$script:response} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-3';SourceUri='https://www.7-zip.org/download.html'})}
        $result.Source.PSObject.Properties.Name | Should -Not -Contain 'Artifacts'
        $result.Source.PSObject.Properties.Name | Should -Not -Contain 'DownloadUri'
    }

    It 'defers GitHub sources to the GitHub provider' {
        Mock Invoke-WebRequest { throw 'Network access must not occur.' } -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {
            param($uri)
            Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-github';SourceUri=$uri})
        } 'https://github.com/audacity/audacity/releases/tag/Audacity-4.0.0'
        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceUnsupported'
        $result.Errors.Code | Should -Contain 'OfficialDownloadPageHostUnsupported'
    }

    It 'rejects non-HTML content' {
        Mock Invoke-WebRequest {[pscustomobject]@{Content='MZ';Headers=@{'Content-Type'='application/octet-stream'}}} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-4';SourceUri='https://example.com/download'})}
        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceUnsupported'
        $result.Errors.Code | Should -Contain 'OfficialDownloadPageContentTypeUnsupported'
    }

    It 'fails deterministically when identity metadata is absent' {
        Mock Invoke-WebRequest {[pscustomobject]@{Content='<html><body><p>Downloads</p></body></html>';Headers=@{'Content-Type'='text/html'}}} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-5';SourceUri='https://example.com/download'})}
        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceResponseInvalid'
        $result.Errors.Code | Should -Contain 'OfficialDownloadPageIdentityMissing'
    }

    It 'does not request an unsupported URI scheme' {
        Mock Invoke-WebRequest {throw 'Network access must not occur.'} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-6';SourceUri='ftp://example.com/download'})}
        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceUnsupported'
    }
}
