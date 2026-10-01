BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:officialPath = Join-Path $script:testRoot 'plugins/Wintainium.provider.official-download-page/Wintainium.provider.official-download-page.psm1'
    Import-Module $script:officialPath -Force
}

Describe 'Wintainium official download page provider release discovery' {
    It 'normalizes multiple dated release sections and their supported artifacts' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h1>Downloads</h1>
<h2>7-Zip 26.03 (2026-09-03)</h2>
<p>Current release</p>
<ul>
<li><a href="/a/7z2603-x64.exe">7-Zip for x64</a></li>
<li><a href="/a/7z2603-x86.exe">7-Zip for x86</a></li>
<li><a href="/a/7z2603-arm64.exe">7-Zip for ARM64</a></li>
<li><a href="/a/7z2603.msi">MSI installer</a></li>
<li><a href="/documentation.html">Documentation</a></li>
</ul>
<h2>7-Zip 23.01 (2023-06-20)</h2>
<ul>
<li><a href="/a/7z2301-x64.exe">7-Zip for x64</a></li>
<li><a href="/a/7z2301-x86.exe">7-Zip for x86</a></li>
</ul>
</body>
</html>
'@
            }
        } -ModuleName Wintainium.provider.official-download-page

        $request = [pscustomobject]@{
            OperationId = 'page-release-test-1'
            Settings = [ordered]@{ pageUri = 'https://www.example.com/download.html' }
        }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 2

        $latest = @($result.Releases)[0]
        $latest.Version | Should -Be '26.03'
        $latest.Channel | Should -Be 'stable'
        $latest.PublishedAt.ToString('yyyy-MM-dd') | Should -Be '2026-09-03'
        @($latest.Artifacts).Count | Should -Be 4

        (@($latest.Artifacts | Where-Object { $_.Architecture -eq 'x64' })).Count | Should -Be 1
        (@($latest.Artifacts | Where-Object { $_.Architecture -eq 'x86' })).Count | Should -Be 1
        (@($latest.Artifacts | Where-Object { $_.Architecture -eq 'arm64' })).Count | Should -Be 1
        (@($latest.Artifacts | Where-Object { $_.Format -eq 'msi' })).Count | Should -Be 1

        $older = @($result.Releases)[1]
        $older.Version | Should -Be '23.01'
        $older.PublishedAt.ToString('yyyy-MM-dd') | Should -Be '2023-06-20'
        @($older.Artifacts).Count | Should -Be 2
    }

    It 'ignores unsupported and non-download links and resolves relative links against the source page' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h2>Example 1.2.3 (2026-01-02)</h2>
<a href="/downloads/example-x64.exe">x64</a>
<a href="https://cdn.example.net/example-x86.msi">external mirror</a>
<a href="/checksums/example.txt">checksums</a>
<a href="#documentation">documentation</a>
</body>
</html>
'@
            }
        } -ModuleName Wintainium.provider.official-download-page

        $request = [pscustomobject]@{
            OperationId = 'page-release-test-2'
            Settings = [ordered]@{ pageUri = 'https://www.example.com/download.html' }
        }

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request $request

        $result.IsSuccessful | Should -Be $true
        @($result.Releases).Count | Should -Be 1
        @($result.Releases[0].Artifacts).Count | Should -Be 2
        @($result.Releases[0].Artifacts)[0].Uri | Should -Be 'https://www.example.com/downloads/example-x64.exe'
        @($result.Releases[0].Artifacts)[1].Uri | Should -Be 'https://cdn.example.net/example-x86.msi'
    }

    It 'returns no releases when the page contains no versioned release sections' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = '<html><body><h1>Downloads</h1><p>Documentation only.</p></body></html>'
            }
        } -ModuleName Wintainium.provider.official-download-page

        $request = [pscustomobject]@{
            OperationId = 'page-release-test-3'
            Settings = [ordered]@{ pageUri = 'https://www.example.com/download.html' }
        }

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request $request

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'NoReleasesFound'
        @($result.Releases).Count | Should -Be 0
    }
}
