BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

    $script:githubPath = Join-Path $script:testRoot 'plugins/Wintainium.provider.github-releases/Wintainium.provider.github-releases.psm1'
    Import-Module $script:githubPath -Force

    $script:officialPath = Join-Path $script:testRoot 'plugins/Wintainium.provider.official-download-page/Wintainium.provider.official-download-page.psm1'
    Import-Module $script:officialPath -Force
}

Describe 'Wintainium GitHub provider icon discovery' {
    BeforeEach {
        $script:request = [pscustomobject]@{
            OperationId = 'icon-test-1'
            Source = [pscustomobject]@{
                ProviderSettings = [ordered]@{ repository = 'example/example' }
            }
        }
    }

    It 'resolves an explicit same-host icon from the official homepage' {
        Mock Invoke-RestMethod {
            [pscustomobject]@{ homepage = 'https://example.com/' }
        } -ModuleName Wintainium.provider.github-releases
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Links = @(
                    [pscustomobject]@{ rel = 'icon'; href = '/favicon.ico' }
                )
            }
        } -ModuleName Wintainium.provider.github-releases

        $result = Wintainium.provider.github-releases\Invoke-WintainiumProviderIconDiscovery -Request $script:request

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'IconResolved'
        $result.IconUri | Should -Be 'https://example.com/favicon.ico'
    }

    It 'rejects an icon hosted on a different origin' {
        Mock Invoke-RestMethod {
            [pscustomobject]@{ homepage = 'https://example.com/' }
        } -ModuleName Wintainium.provider.github-releases
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Links = @(
                    [pscustomobject]@{ rel = 'icon'; href = 'https://cdn.example.net/icon.png' }
                )
            }
        } -ModuleName Wintainium.provider.github-releases

        $result = Wintainium.provider.github-releases\Invoke-WintainiumProviderIconDiscovery -Request $script:request

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'NoTrustedIcon'
        $result.IconUri | Should -BeNullOrEmpty
    }

    It 'returns no trusted icon when the repository has no official homepage' {
        Mock Invoke-RestMethod {
            [pscustomobject]@{ homepage = $null }
        } -ModuleName Wintainium.provider.github-releases

        $result = Wintainium.provider.github-releases\Invoke-WintainiumProviderIconDiscovery -Request $script:request

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'NoTrustedIcon'
        $result.IconUri | Should -BeNullOrEmpty
        Should -Invoke Invoke-RestMethod -ModuleName Wintainium.provider.github-releases -Times 1
        Should -Invoke Invoke-WebRequest -ModuleName Wintainium.provider.github-releases -Times 0
    }
}

Describe 'Wintainium official download page provider icon discovery' {
    It 'resolves an explicit same-host icon' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = '<html><head><link rel="icon" href="/favicon.ico"></head></html>'
            }
        } -ModuleName Wintainium.provider.official-download-page

        $request = [pscustomobject]@{
            OperationId = 'page-icon-test-1'
            Source = [pscustomobject]@{ Homepage = 'https://example.com/downloads' }
        }

        $result = Wintainium.provider.official-download-page\Invoke-WintainiumProviderIconDiscovery -Request $request

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'IconResolved'
        $result.IconUri | Should -Be 'https://example.com/favicon.ico'
    }

    It 'rejects an icon hosted on a different origin' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = '<html><head><link rel="icon" href="https://cdn.example.net/icon.png"></head></html>'
            }
        } -ModuleName Wintainium.provider.official-download-page

        $request = [pscustomobject]@{
            OperationId = 'page-icon-test-2'
            Source = [pscustomobject]@{ Homepage = 'https://example.com/downloads' }
        }

        $result = Invoke-WintainiumProviderIconDiscovery -Request $request

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'NoTrustedIcon'
        $result.IconUri | Should -BeNullOrEmpty
    }
}
