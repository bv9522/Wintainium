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

    It 'captures official-page MD5 claims only when there is one checksum per artifact' {
        Mock -ModuleName Wintainium.provider.official-download-page Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<h2>Release 11.50a</h2>
<p>Full setup / 6.37 MB / MD5 Checksum: CC180CA4A6204B1BAD8562C79C805F4B</p>
<p>Portable / 5.46 MB / MD5 Checksum: F9963A9DB7F1A826353F486C0E5216FC</p>
<a href="https://downloads.example.com/ac-11_50a.exe">Full setup</a>
<a href="https://downloads.example.com/ac-11_50a.zip">Portable</a>
'@
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            Settings = [pscustomobject]@{
                pageUri = 'https://example.com/download/'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        $artifacts = @($result.Releases[0].Artifacts)
        $artifacts.Count | Should -Be 2
        $artifacts[0].FileName | Should -Be 'ac-11_50a.exe'
        $artifacts[0].Hashes.Count | Should -Be 1
        $artifacts[0].Hashes[0].Algorithm | Should -Be 'MD5'
        $artifacts[0].Hashes[0].Value | Should -Be 'CC180CA4A6204B1BAD8562C79C805F4B'
        $artifacts[0].Hashes[0].Source | Should -Be 'OfficialDownloadPageChecksum'
        $artifacts[1].FileName | Should -Be 'ac-11_50a.zip'
        $artifacts[1].Hashes[0].Value | Should -Be 'F9963A9DB7F1A826353F486C0E5216FC'
    }

    It 'associates a single visible SHA256 checksum with the first artifact only when the claim precedes artifact links' {
        Mock -ModuleName Wintainium.provider.official-download-page Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<h2>Download Core Temp 1.21</h2>
<p>Download SHA-256: FBF053DB5567D55D20F8D54B8930E95914FFD44073A62ED71AC9048C89D4ECB6</p>
<a href="https://downloads.example.com/Core-Temp-setup-v1.21.exe">Download Core Temp</a>
<a href="https://downloads.example.com/CoreTemp32.zip">32 Bit</a>
<a href="https://downloads.example.com/CoreTemp64.zip">64 Bit</a>
'@
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            Settings = [pscustomobject]@{ pageUri = 'https://example.com/coretemp/' }
        })

        $result.IsSuccessful | Should -BeTrue
        $artifacts = @($result.Releases[0].Artifacts)
        $artifacts.Count | Should -Be 3
        $artifacts[0].FileName | Should -Be 'Core-Temp-setup-v1.21.exe'
        $artifacts[0].Hashes.Count | Should -Be 1
        $artifacts[0].Hashes[0].Algorithm | Should -Be 'SHA256'
        $artifacts[0].Hashes[0].Value | Should -Be 'FBF053DB5567D55D20F8D54B8930E95914FFD44073A62ED71AC9048C89D4ECB6'
        $artifacts[0].Hashes[0].Source | Should -Be 'OfficialDownloadPageChecksum'
        $artifacts[1].Hashes.Count | Should -Be 0
        $artifacts[2].Hashes.Count | Should -Be 0
    }

    It 'does not infer SHA256 associations from checksum order when multiple claims are visible' {
        Mock -ModuleName Wintainium.provider.official-download-page Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<h2>Download App 1.0.0</h2>
<p>SHA-256: FBF053DB5567D55D20F8D54B8930E95914FFD44073A62ED71AC9048C89D4ECB6</p>
<p>SHA-256: 0859C524B8A63551848F0C246ABDDCB1D0B7B656B0FBFE879F8D85E61A9E6EDD</p>
<a href="https://downloads.example.com/app.exe">Installer</a>
<a href="https://downloads.example.com/app.zip">Portable</a>
'@
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            Settings = [pscustomobject]@{ pageUri = 'https://example.com/download/' }
        })

        $result.IsSuccessful | Should -BeTrue
        @($result.Releases[0].Artifacts).Count | Should -Be 2
        @($result.Releases[0].Artifacts)[0].Hashes.Count | Should -Be 0
        @($result.Releases[0].Artifacts)[1].Hashes.Count | Should -Be 0
    }

    It 'associates SHA256 checksums with the matching filenames in a checksum table' {
        Mock -ModuleName Wintainium.provider.official-download-page Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<h2>App 1.0.0</h2>
<a href="https://downloads.example.com/app-setup.exe">Download</a>
<table>
<tr><th>File</th><th>SHA-256</th></tr>
<tr><td><a href="https://downloads.example.com/App32.zip">App32.zip</a></td><td>20BA206A058CCC098BF40F68833FEDA59463509D8F1984A36017A175C30B32AD</td></tr>
<tr><td><a href="https://downloads.example.com/App64.zip">App64.zip</a></td><td>407A5DFFBCAF43098200B7F6AE7875974CB7F1891B535837055DE09A1F3D154F</td></tr>
</table>
'@
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            Settings = [pscustomobject]@{ pageUri = 'https://example.com/download/' }
        })

        $result.IsSuccessful | Should -BeTrue
        $artifacts = @($result.Releases[0].Artifacts)
        $artifacts.Count | Should -Be 3
        (@($artifacts[1].Hashes | Where-Object { $_.Algorithm -eq 'SHA256' })[0]).Value | Should -Be '20BA206A058CCC098BF40F68833FEDA59463509D8F1984A36017A175C30B32AD'
        (@($artifacts[2].Hashes | Where-Object { $_.Algorithm -eq 'SHA256' })[0]).Value | Should -Be '407A5DFFBCAF43098200B7F6AE7875974CB7F1891B535837055DE09A1F3D154F'
        @($artifacts[0].Hashes | Where-Object { $_.Algorithm -eq 'SHA256' }).Count | Should -Be 0
    }

    It 'does not guess the target artifact for a lone SHA256 checksum appearing after download links' {
        Mock -ModuleName Wintainium.provider.official-download-page Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<h2>Download App 1.0.0</h2>
<a href="https://downloads.example.com/app.exe">Installer</a>
<a href="https://downloads.example.com/app.zip">Portable</a>
<p>SHA-256: FBF053DB5567D55D20F8D54B8930E95914FFD44073A62ED71AC9048C89D4ECB6</p>
'@
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            Settings = [pscustomobject]@{ pageUri = 'https://example.com/download/' }
        })

        $result.IsSuccessful | Should -BeTrue
        @($result.Releases[0].Artifacts).Count | Should -Be 2
        @($result.Releases[0].Artifacts)[0].Hashes.Count | Should -Be 0
        @($result.Releases[0].Artifacts)[1].Hashes.Count | Should -Be 0
    }

    It 'does not guess MD5-to-artifact association when checksum and artifact counts differ' {
        Mock -ModuleName Wintainium.provider.official-download-page Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<h2>Release 1.0.0</h2>
<p>MD5 Checksum: CC180CA4A6204B1BAD8562C79C805F4B</p>
<a href="https://downloads.example.com/app.exe">Download</a>
<a href="https://downloads.example.com/app.zip">Portable</a>
'@
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            Settings = [pscustomobject]@{
                pageUri = 'https://example.com/download/'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        @($result.Releases[0].Artifacts)[0].Hashes.Count | Should -Be 0
        @($result.Releases[0].Artifacts)[1].Hashes.Count | Should -Be 0
    }
}
