BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:githubProviderPath = Join-Path $script:testRoot 'plugins/Wintainium.provider.github-releases/Wintainium.provider.github-releases.psm1'
    $script:officialPageProviderPath = Join-Path $script:testRoot 'plugins/Wintainium.provider.official-download-page/Wintainium.provider.official-download-page.psm1'

    Import-Module $script:githubProviderPath -Force
    Import-Module $script:officialPageProviderPath -Force
}

Describe 'Phase 12.10B real-world source validation' {
    It 'resolves a live GitHub repository source through the GitHub resolver' {
        $result = & (Get-Module Wintainium.provider.github-releases) {
            param($request)
            Invoke-WintainiumProviderSourceResolution -Request $request
        } ([pscustomobject]@{
            OperationId = 'phase-12-10b-github-1'
            SourceUri = 'https://github.com/PCSX2/pcsx2'
        })

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Resolved'
        $result.Source.ApplicationId | Should -Be 'github.pcsx2.pcsx2'
        $result.Source.ProviderId | Should -Be 'Wintainium.provider.github-releases'
        $result.Source.ProviderSettings.repository | Should -Be 'PCSX2/pcsx2'
    }

    It 'resolves a live GitHub release source without changing release context' {
        $result = & (Get-Module Wintainium.provider.github-releases) {
            param($request)
            Invoke-WintainiumProviderSourceResolution -Request $request
        } ([pscustomobject]@{
            OperationId = 'phase-12-10b-github-2'
            SourceUri = 'https://github.com/microsoft/PowerToys/releases'
        })

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Resolved'
        $result.Source.ProviderSettings.repository | Should -Be 'microsoft/PowerToys'
        $result.Source.SourceContext.PSObject.Properties.Name | Should -Not -Contain 'releaseTag'
    }

    It 'resolves the live 7-Zip official download page' {
        $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
            OperationId = 'phase-12-10b-page-1'
            SourceUri = 'https://www.7-zip.org/download.html'
        })

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Resolved'
        $result.Source.Name | Should -Be '7-Zip'
        $result.Source.ProviderId | Should -Be 'Wintainium.provider.official-download-page'
        $result.Source.ProviderSettings.pageUri | Should -Be 'https://www.7-zip.org/download.html'
        $result.Source.PSObject.Properties.Name | Should -Not -Contain 'Artifacts'
        $result.Source.PSObject.Properties.Name | Should -Not -Contain 'DownloadUri'
    }

    It 'resolves the live VLC official download page' {
        $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
            OperationId = 'phase-12-10b-page-2'
            SourceUri = 'https://www.videolan.org/vlc/'
        })

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Resolved'
        $result.Source.Name | Should -Be 'VLC media player'
        $result.Source.Publisher | Should -Be 'VideoLAN'
        $result.Source.ProviderId | Should -Be 'Wintainium.provider.official-download-page'
    }
}
