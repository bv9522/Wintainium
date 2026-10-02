BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:providerPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.provider.official-download-page/Wintainium.provider.official-download-page.psm1'
    Import-Module $script:providerPath -Force
}

Describe 'Official download page verification evidence discovery' {
    It 'enriches a GitHub-hosted artifact linked from an official page with the exact GitHub asset SHA256 digest' {
        Mock -ModuleName Wintainium.provider.official-download-page Invoke-WebRequest {
            [pscustomobject]@{
                Content = '<h2>Download 7-Zip 26.03 (2026-09-03)</h2><a href="https://github.com/ip7z/7zip/releases/download/26.03/7z2603-x64.exe">Download</a>'
            }
        }

        Mock -ModuleName Wintainium.provider.official-download-page Invoke-RestMethod {
            [pscustomobject]@{
                tag_name = '26.03'
                assets = @(
                    [pscustomobject]@{
                        browser_download_url = 'https://github.com/ip7z/7zip/releases/download/26.03/7z2603-x64.exe'
                        digest = 'sha256:0859c524b8a63551848f0c246abddcb1d0b7b656b0fbfe879f8d85e61a9e6edd'
                    }
                )
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            Settings = [pscustomobject]@{
                pageUri = 'https://www.7-zip.org/download.html'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        $artifact = $result.Releases[0].Artifacts[0]
        $artifact.Uri | Should -Be 'https://github.com/ip7z/7zip/releases/download/26.03/7z2603-x64.exe'
        $artifact.Hashes.Count | Should -Be 1
        $artifact.Hashes[0].Algorithm | Should -Be 'SHA256'
        $artifact.Hashes[0].Value | Should -Be '0859C524B8A63551848F0C246ABDDCB1D0B7B656B0FBFE879F8D85E61A9E6EDD'
    }

    It 'does not invent verification evidence for non-GitHub artifacts' {
        Mock -ModuleName Wintainium.provider.official-download-page Invoke-WebRequest {
            [pscustomobject]@{
                Content = '<h2>Download App 1.0.0 (2026-09-03)</h2><a href="https://downloads.example.com/app-1.0.0.exe">Download</a>'
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            Settings = [pscustomobject]@{
                pageUri = 'https://example.com/download.html'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Releases[0].Artifacts[0].Hashes.Count | Should -Be 0
    }
}
