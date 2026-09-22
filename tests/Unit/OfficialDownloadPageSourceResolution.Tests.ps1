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

    It 'accepts supported metadata in different attribute order' {
        Mock Invoke-WebRequest {[pscustomobject]@{Content='<html><head><meta content="VideoLAN" property="og:site_name"><meta content="VLC media player" name="application-name"><title>VLC download</title></head></html>';Headers=@{'Content-Type'='text/html'}}} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-2';SourceUri='https://www.videolan.org/vlc/'})}
        $result.IsSuccessful | Should -Be $true
        $result.Source.Name | Should -Be 'VLC media player'
        $result.Source.Publisher | Should -Be 'VideoLAN'
    }

    It 'does not return download artifacts during source resolution' {
        Mock Invoke-WebRequest {$script:response} -ModuleName Wintainium.provider.official-download-page
        $result=& (Get-Module Wintainium.provider.official-download-page) {Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{OperationId='page-test-3';SourceUri='https://www.7-zip.org/download.html'})}
        $result.Source.PSObject.Properties.Name | Should -Not -Contain 'Artifacts'
        $result.Source.PSObject.Properties.Name | Should -Not -Contain 'DownloadUri'
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
