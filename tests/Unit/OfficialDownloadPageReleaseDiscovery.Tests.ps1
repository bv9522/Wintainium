BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:officialPath = Join-Path $script:testRoot 'plugins/Wintainium.provider.official-download-page/Wintainium.provider.official-download-page.psm1'
    Import-Module $script:officialPath -Force
}

Describe 'Wintainium official download page provider release discovery' {

    It 'discovers versioned SourceForge files whose download URLs end in /download' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<head><title>Peace Equalizer APO Extension Files</title></head>
<body>
<h1>Peace Equalizer APO Extension Files</h1>
<div class="files">
  <a href="/projects/peace-equalizer-apo-extension/files/Peace/1.6.9.11/PeaceSetup.exe/download">PeaceSetup.exe</a>
  <a href="/projects/peace-equalizer-apo-extension/files/Peace/1.6.9.11/Peace_x64.zip/download">Peace_x64.zip</a>
</div>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/' }
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'sourceforge-peace-file-listing'
            Settings = [pscustomobject]@{
                pageUri = 'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1
        $release = $result.Releases[0]
        $release.Version | Should -Be '1.6.9.11'
        @($release.Artifacts).Count | Should -Be 2
        @($release.Artifacts | Where-Object FileName -eq 'PeaceSetup.exe').Count | Should -Be 1
        @($release.Artifacts | Where-Object FileName -eq 'Peace_x64.zip').Count | Should -Be 1
        @($release.Artifacts | Where-Object Uri -match '/PeaceSetup\.exe/download$').Count | Should -Be 1

        $parseEvent = @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryParsingCompleted')[-1]
        $parseEvent.Context.Outcome | Should -Be 'ReleasesParsed'
        $parseEvent.Context.ParsedReleaseCount | Should -Be 1
        $parseEvent.Context.ParsedArtifactCount | Should -Be 2
    }

    It 'discovers SourceForge root-level files using the current version label' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
  <a href="/projects/peace-equalizer-apo-extension/files/PeaceSetup.exe/download">PeaceSetup.exe</a>
  <a href="/projects/peace-equalizer-apo-extension/files/Peace.exe/download">Peace.exe</a>
  <a href="/projects/peace-equalizer-apo-extension/files/64 bits version/Peace64.exe/download">Peace64.exe</a>
  <p>From version 1.5.0.1 all Peace executables have a code signing certificate.</p>
  <h2>Version 1.6.9.11</h2>
  <p>Released 2025-11-02</p>
  <h2>Version 1.6.7.10</h2>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/' }
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'sourceforge-peace-root-files'
            Settings = [pscustomobject]@{
                pageUri = 'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1
        $result.Releases[0].Version | Should -Be '1.6.9.11'
        @($result.Releases[0].Artifacts).Count | Should -Be 3
        @($result.Releases[0].Artifacts | Where-Object FileName -eq 'PeaceSetup.exe').Count | Should -Be 1
        @($result.Releases[0].Artifacts | Where-Object FileName -eq 'Peace.exe').Count | Should -Be 1
        @($result.Releases[0].Artifacts | Where-Object FileName -eq 'Peace64.exe').Count | Should -Be 1
    }

    It 'discovers SourceForge root-level files when the current version is a standalone non-heading label' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
  <a href="/projects/example-project/files/ExampleSetup.exe/download">ExampleSetup.exe</a>
  <a href="/projects/example-project/files/Example.exe/download">Example.exe</a>
  <p>From version 1.2.0 all executables have a code signing certificate.</p>
  <div class="release-version">Version 2.4.1</div>
  <p>Released 2026-08-14</p>
  <div class="history">Version 2.3.0</div>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://sourceforge.net/projects/example-project/files/' }
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'sourceforge-root-files-non-heading-version'
            Settings = [pscustomobject]@{
                pageUri = 'https://sourceforge.net/projects/example-project/files/'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1
        $result.Releases[0].Version | Should -Be '2.4.1'
        @($result.Releases[0].Artifacts).Count | Should -Be 2
        @($result.Releases[0].Artifacts | Where-Object FileName -eq 'ExampleSetup.exe').Count | Should -Be 1
        @($result.Releases[0].Artifacts | Where-Object FileName -eq 'Example.exe').Count | Should -Be 1

        $parseEvent = @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryParsingCompleted')[-1]
        $parseEvent.Context.DownloadArtifactCandidateCount | Should -Be 2
        $parseEvent.Context.ParsedReleaseVersions[0] | Should -Be '2.4.1'
    }

    It 'matches SourceForge release-note version to the newest supported file-row date' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h1>Peace Equalizer APO Extension Files</h1>
<table>
<tr title="PeaceSetup.exe" class="file">
  <th><a href="https://sourceforge.net/projects/peace-equalizer-apo-extension/files/PeaceSetup.exe/download"><span class="name">PeaceSetup.exe</span></a></th>
  <td><abbr title="2025-11-02 11:46:55 UTC">2025-11-02</abbr></td>
</tr>
</table>
<a href="/projects/peace-equalizer-apo-extension/files/latest/download">Download Latest Version PeaceSetup.exe (55.7 MB)</a>
<div class="description">
  <pre>Version 1.6.9.11
Released 2025-11-02
added: improved configuration editor

Version 1.6.8.10
Released 2024-05-17</pre>
</div>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/' }
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'sourceforge-peace-dated-release-notes'
            Settings = [pscustomobject]@{
                pageUri = 'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1
        $result.Releases[0].Version | Should -Be '1.6.9.11'
        @($result.Releases[0].Artifacts | Where-Object FileName -eq 'PeaceSetup.exe').Count | Should -BeGreaterThan 0
        $parseEvent = @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryParsingCompleted')[-1]
        $parseEvent.Context.ParsedReleaseCount | Should -Be 1
    }

    It 'does not use a historical SourceForge version when its release date differs from the latest file row' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h1>Example Project Files</h1>
<table>
<tr title="ExampleSetup.exe" class="file">
  <th><a href="/projects/example-project/files/ExampleSetup.exe/download"><span class="name">ExampleSetup.exe</span></a></th>
  <td><abbr title="2025-11-02 11:46:55 UTC">2025-11-02</abbr></td>
</tr>
</table>
<div class="description">
  <pre>Version 1.2.3
Released 2024-05-17</pre>
</div>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://sourceforge.net/projects/example-project/files/' }
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'sourceforge-reject-undated-current-version'
            Settings = [pscustomobject]@{
                pageUri = 'https://sourceforge.net/projects/example-project/files/'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'NoReleasesFound'
        @($result.Releases).Count | Should -Be 0
    }

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

        $parseEvent = @($result.LogEvents | Where-Object { $_.EventName -eq 'ReleaseDiscoveryParsingCompleted' })[-1]
        @($parseEvent.Context.ParsedReleaseVersions).Count | Should -Be 2
        $parseEvent.Context.ParsedReleaseVersions[0] | Should -Be '26.03'
        $parseEvent.Context.ParsedReleaseVersions[1] | Should -Be '23.01'
    }

    It 'discovers release sections that are presented as download labels instead of headings' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<p>Download Example 26.03 (2026-09-03) for Windows:</p>
<table>
<tr><td><a href="releases/example-26.03-x64.exe">Download</a> .exe 64-bit Windows x64</td></tr>
<tr><td><a href="releases/example-26.03-x86.exe">Download</a> .exe 32-bit Windows x86</td></tr>
<tr><td><a href="releases/example-26.03.msi">Download</a> .msi 64-bit Windows x64</td></tr>
</table>
<p>Download Example 25.01 (2025-01-10):</p>
<a href="releases/example-25.01-x64.exe">Download</a>
</body>
</html>
'@
            }
        } -ModuleName Wintainium.provider.official-download-page

        $request = [pscustomobject]@{
            OperationId = 'page-release-test-unheaded'
            Settings = [ordered]@{ pageUri = 'https://www.example.com/download.html' }
        }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 2
        @($result.Releases)[0].Version | Should -Be '26.03'
        @($result.Releases)[0].PublishedAt.ToString('yyyy-MM-dd') | Should -Be '2026-09-03'
        @($result.Releases)[0].Artifacts.Count | Should -Be 3
        @($result.Releases)[0].Artifacts[0].Architecture | Should -Be 'x64'
        @($result.Releases)[0].Artifacts[1].Architecture | Should -Be 'x86'
        @($result.Releases)[0].Artifacts[2].Format | Should -Be 'msi'
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

    It 'extracts a version from labeled revision metadata within a download section' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h4>Example Graphics Software</h4>
<div>Revision Number</div>
<div>Adrenalin 26.5.2 (WHQL Recommended)</div>
<div>File Size</div>
<div>623 MB</div>
<div>Release Date</div>
<div>2026-05-21</div>
<a href="https://downloads.example.test/example-26.5.2-x64.exe">Download</a>
</body>
</html>
'@
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'page-release-revision-metadata'
            Settings = [pscustomobject]@{ pageUri = 'https://www.example.test/product/downloads.html' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1
        $result.Releases[0].Version | Should -Be '26.5.2'
        $result.Releases[0].PublishedAt.ToString('yyyy-MM-dd') | Should -Be '2026-05-21'
        @($result.Releases[0].Artifacts).Count | Should -Be 1
        $result.Releases[0].Artifacts[0].Uri | Should -Be 'https://downloads.example.test/example-26.5.2-x64.exe'
    }

    It 'does not invent a versioned release from an unversioned driver landing page' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h1>Drivers and Support for Processors and Graphics</h1>
<h2>Windows 10/11 Drivers</h2>
<p>Auto-detect and install driver updates for graphics and chipsets.</p>
<a href="https://drivers.example.test/auto-detect.exe">Download Windows Drivers</a>
<h2>Linux Drivers</h2>
</body>
</html>
'@
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'page-release-unversioned-landing'
            Settings = [pscustomobject]@{ pageUri = 'https://www.example.com/drivers.html' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'NoReleasesFound'
        @($result.Releases).Count | Should -Be 0
        $parseEvent = @($result.LogEvents | Where-Object { $_.EventName -eq 'ReleaseDiscoveryParsingCompleted' })[-1]
        $parseEvent.Context.Outcome | Should -Be 'ReleaseSectionsProducedNoArtifacts'
        $parseEvent.Context.DownloadArtifactCandidateCount | Should -Be 1
        $parseEvent.Context.ParsedReleaseCount | Should -Be 0
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

    It 'preserves the publisher download URL and source-page provenance for a cross-host artifact' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h2>Release 11.50a</h2>
<p>Full setup / 6.37 MB / MD5 checksum published separately.</p>
<a href="https://pubfiles.petges.lu/ac-11_50a.exe">Full setup</a>
<a href="https://pubfiles.petges.lu/ac-11_50a.zip">Portable</a>
</body>
</html>
'@
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'attribute-changer-source-provenance'
            Settings = [pscustomobject]@{ pageUri = 'https://www.petges.lu/download/' }
        })

        $result.IsSuccessful | Should -BeTrue
        $artifact = @($result.Releases[0].Artifacts)[0]
        $artifact.Uri | Should -Be 'https://pubfiles.petges.lu/ac-11_50a.exe'
        $artifact.FileName | Should -Be 'ac-11_50a.exe'
        $artifact.SourcePageUri | Should -Be 'https://www.petges.lu/download/'
        $artifact.Hashes.Count | Should -Be 0
    }
    It 'skips empty release headings without aborting discovery of later valid releases' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h2></h2>
<a href="/downloads/unrelated.exe">Download</a>
<h2>Example 2.4.0</h2>
<a href="/downloads/example-2.4.0-x64.exe">Download</a>
</body>
</html>
'@
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'page-release-empty-heading'
            Settings = [pscustomobject]@{ pageUri = 'https://www.example.test/downloads.html' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1
        $result.Releases[0].Version | Should -Be '2.4.0'
        @($result.Releases[0].Artifacts).Count | Should -Be 1
    }


    It 'classifies an installer as neutral when official release metadata explicitly supports both 32-bit and 64-bit' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h2>Example 3.2.1</h2>
<p>The Windows installer supports both 32-bit and 64-bit Windows.</p>
<a href="/downloads/example-setup.exe">Download installer</a>
<a href="/downloads/example-x64.zip">64-bit portable archive</a>
</body>
</html>
'@
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'page-release-dual-architecture'
            Settings = [pscustomobject]@{ pageUri = 'https://www.example.test/downloads.html' }
        })

        $result.IsSuccessful | Should -BeTrue
        @($result.Releases).Count | Should -Be 1
        $artifacts = @($result.Releases[0].Artifacts)
        @($artifacts | Where-Object FileName -eq 'example-setup.exe').Count | Should -Be 1
        (@($artifacts | Where-Object FileName -eq 'example-setup.exe')[0]).Architecture | Should -Be 'neutral'
        (@($artifacts | Where-Object FileName -eq 'example-x64.zip')[0]).Architecture | Should -Be 'x64'
    }

    It 'discovers Core Temp current release and excludes language-pack and historical downloads' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<div>Core Temp 1.21:</div>
<p>Download SHA-256: FBF053DB5567D55D20F8D54B8930E95914FFD44073A62ED71AC9048C89D4ECB6 MD5: 93CFE187305BF73A4054079538B711EC</p>
<a href="/CoreTemp/Core-Temp-setup-v1.21.exe">Download Core Temp</a>
<p>More downloads... Download the standalone version of Core Temp:</p>
<a href="/CoreTemp/CoreTemp32.zip">32 Bit</a>
<a href="/CoreTemp/CoreTemp64.zip">64 Bit</a>
<p>Language packs</p>
<a href="/CoreTemp/translation-tool.zip">Download the translation tool</a>
<p>Past releases</p>
<table>
<tr><td>1.20.1</td><td><a href="/CoreTemp/CT1201.zip">CT1201.zip</a></td></tr>
<tr><td>1.19.5</td><td><a href="/CoreTemp/CT1195.zip">CT1195.zip</a></td></tr>
</table>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://www.alcpu.com/CoreTemp/' }
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'core-temp-current-release'
            Settings = [pscustomobject]@{ pageUri = 'https://www.alcpu.com/CoreTemp/' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1
        $release = $result.Releases[0]
        $release.Version | Should -Be '1.21'
        @($release.Artifacts).Count | Should -Be 3
        @($release.Artifacts | Where-Object { $_.FileName -eq 'Core-Temp-setup-v1.21.exe' }).Count | Should -Be 1
        $setupArtifact = (@($release.Artifacts | Where-Object { $_.FileName -eq 'Core-Temp-setup-v1.21.exe' })[0])
        $setupArtifact.Architecture | Should -Be 'unknown'
        @($setupArtifact.Hashes | Where-Object { $_.Algorithm -eq 'SHA256' }).Count | Should -Be 1
        (@($setupArtifact.Hashes | Where-Object { $_.Algorithm -eq 'SHA256' })[0]).Value | Should -Be 'FBF053DB5567D55D20F8D54B8930E95914FFD44073A62ED71AC9048C89D4ECB6'
        @($release.Artifacts | Where-Object { $_.FileName -eq 'CoreTemp32.zip' }).Count | Should -Be 1
        @($release.Artifacts | Where-Object { $_.FileName -eq 'CoreTemp64.zip' }).Count | Should -Be 1
        (@($release.Artifacts | Where-Object { $_.FileName -eq 'CoreTemp32.zip' })[0]).Architecture | Should -Be 'x86'
        (@($release.Artifacts | Where-Object { $_.FileName -eq 'CoreTemp64.zip' })[0]).Architecture | Should -Be 'x64'
        @($release.Artifacts | Where-Object { $_.FileName -match 'translation-tool|CT1201|CT1195' }).Count | Should -Be 0

        $parseEvent = @($result.LogEvents | Where-Object { $_.EventName -eq 'ReleaseDiscoveryParsingCompleted' })[-1]
        $parseEvent.Context.Outcome | Should -Be 'ReleasesParsed'
        $parseEvent.Context.ParsedReleaseVersions[0] | Should -Be '1.21'
    }


    It 'discovers a page-level stable version with Windows-scoped artifacts and dual-architecture support' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h2>Current Stable Version</h2>
<p>The current stable release of GIMP is <strong>3.2.6</strong> (2026-09-10).</p>
<h2>GIMP for Unix-like systems</h2>
<a href="https://download.gimp.org/gimp/v3.2/linux/gimp-3.2.6-x86_64.AppImage">Download GIMP 3.2.6 AppImage for x86_64</a>
<h2>GIMP for macOS</h2>
<a href="https://download.gimp.org/gimp/v3.2/macOS/gimp-3.2.6-x86_64.dmg">Download GIMP 3.2.6 for Intel</a>
<h2>GIMP for Windows</h2>
<a href="https://download.gimp.org/gimp/v3.2/windows/gimp-3.2.6-setup.exe">Download GIMP 3.2.6 for x86_64 and ARM64 directly</a>
<a href="https://www.gimp.org/downloads/" >gimp-3.2.6-setup.exe</a>
<a href="https://download.gimp.org/gimp/v3.2/windows/gimp-3.2.6-setup.exe.torrent">Download via BitTorrent</a>
<h3>Warnings and information</h3>
<p>Supported OS for installer: Windows 10 1903 or newer</p>
<h3>Security</h3>
<ul>
<li><p><strong>SHA256 hash sum for</strong> <code>GIMP-3.2.6-aarch64.AppImage</code>: <code>d1b8271e440dc4e36065ca25f219c0534abd2dfb43aeb033c76b16832d395e19</code></p></li>
<li><p><strong>SHA256 hash sum for</strong> <code>GIMP-3.2.6-x86_64.AppImage</code>: <code>79ea41bc9b06f78fda181849a9ca8e42d83f1124dedb756f4d52352e2465010f</code></p></li>
<li><p><strong>SHA256 hash sum for</strong> <code>gimp-3.2.6-arm64.dmg</code>: <code>854573aec2be6a185aa021109c3c0ca94f210379204b704231bdd191b4060294</code></p></li>
<li><p><strong>SHA256 hash sum for</strong> <code>gimp-3.2.6-x86_64.dmg</code>: <code>ebe633642445d4d6fc6b68e7be7ca581c0b28c18dc9de7747849528c982e5677</code></p></li>
<li><p><strong>SHA256 hash sum for</strong> <code>gimp-3.2.6-setup.exe</code>: <code>9337cccbc01d4098ee7a3dab215b3afbe6ece99c5287c92441d6f12cf541ebca</code></p></li>
</ul>
<h2>Source for version 3.2 (Stable)</h2>
<a href="https://download.gimp.org/gimp/v3.2/windows/">Older Downloads</a>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://www.gimp.org/downloads/' }
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'gimp-stable-windows-release'
            Settings = [pscustomobject]@{ pageUri = 'https://www.gimp.org/downloads/' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1

        $release = $result.Releases[0]
        $release.Version | Should -Be '3.2.6'
        $release.Channel | Should -Be 'stable'
        $release.PublishedAt.ToString('yyyy-MM-dd') | Should -Be '2026-09-10'
        @($release.Artifacts).Count | Should -Be 1
        $release.Artifacts[0].Uri | Should -Be 'https://download.gimp.org/gimp/v3.2/windows/gimp-3.2.6-setup.exe'
        $release.Artifacts[0].FileName | Should -Be 'gimp-3.2.6-setup.exe'
        $release.Artifacts[0].Architecture | Should -Be 'neutral'
        @($release.Artifacts[0].Hashes | Where-Object Algorithm -eq 'SHA256').Count | Should -Be 1
        (@($release.Artifacts[0].Hashes | Where-Object Algorithm -eq 'SHA256')[0]).Value | Should -Be '9337CCCBC01D4098EE7A3DAB215B3AFBE6ECE99C5287C92441D6F12CF541EBCA'

        $parseEvent = @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryParsingCompleted')[-1]
        $parseEvent.Context.Outcome | Should -Be 'ReleasesParsed'
        $parseEvent.Context.ParsedReleaseCount | Should -Be 1
        $parseEvent.Context.ParsedArtifactCount | Should -Be 1
        $parseEvent.Context.PageSha256ClaimCount | Should -Be 5
        $parseEvent.Context.ArtifactsWithSha256EvidenceCount | Should -Be 1
        $parseEvent.Context.AttachedSha256EvidenceCount | Should -Be 1
        $parseEvent.Message | Should -Match '5 page claim\(s\), 1 artifact\(s\) with evidence, 1 attached claim\(s\)'
        $parseEvent.Context.ParsedReleaseVersions[0] | Should -Be '3.2.6'
    }


    It 'associates a filename-specific SHA256 checksum when security metadata is in a separate heading section' {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h2>Example 3.2.6</h2>
<p>Current stable release.</p>
<a href="/downloads/example-3.2.6-setup.exe">Download Example</a>
<h3>Security</h3>
<p>SHA256 hash sum for <code>example-3.2.6-setup.exe</code>: <code>9337cccbc01d4098ee7a3dab215b3afbe6ece99c5287c92441d6f12cf541ebca</code></p>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://www.example.test/downloads/' }
            }
        } -ModuleName Wintainium.provider.official-download-page

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'checksum-across-heading-sections'
            Settings = [pscustomobject]@{ pageUri = 'https://www.example.test/downloads/' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1
        $artifact = @($result.Releases[0].Artifacts)[0]
        $artifact.FileName | Should -Be 'example-3.2.6-setup.exe'
        @($artifact.Hashes | Where-Object Algorithm -eq 'SHA256').Count | Should -Be 1
        (@($artifact.Hashes | Where-Object Algorithm -eq 'SHA256')[0]).Value | Should -Be '9337CCCBC01D4098EE7A3DAB215B3AFBE6ECE99C5287C92441D6F12CF541EBCA'
    }

}

Describe 'Official download page query-declared artifact filenames' {
    It 'discovers a same-origin wrapper download whose supported filename is declared in the file query parameter' {
        Mock Invoke-WebRequest -ModuleName 'Wintainium.provider.official-download-page' {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h2>HandBrake 1.11.2</h2>
<p>Windows download</p>
<a href="https://handbrake.fr/rotation.php?file=HandBrake-1.11.2-x86_64-Win_GUI.exe">Download HandBrake</a>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://handbrake.fr/downloads.php' }
            }
        }

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'handbrake-query-filename'
            Settings = [pscustomobject]@{ pageUri = 'https://handbrake.fr/downloads.php' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1
        $artifact = @($result.Releases[0].Artifacts)[0]
        $artifact.FileName | Should -Be 'HandBrake-1.11.2-x86_64-Win_GUI.exe'
        $artifact.Format | Should -Be 'exe'
        $artifact.Architecture | Should -Be 'x64'
        $artifact.Uri | Should -Be 'https://handbrake.fr/rotation.php?file=HandBrake-1.11.2-x86_64-Win_GUI.exe'
        $artifact.SourcePageUri | Should -Be 'https://handbrake.fr/downloads.php'

        $parseEvent = @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryParsingCompleted')[-1]
        $parseEvent.Context.DownloadArtifactCandidateCount | Should -Be 1
        $parseEvent.Context.ParsedArtifactCount | Should -Be 1
    }

    It 'rejects cross-origin query-declared filenames and ambiguous filename parameters' {
        Mock Invoke-WebRequest -ModuleName 'Wintainium.provider.official-download-page' {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h2>Example 1.2.3</h2>
<a href="https://cdn.example.test/rotation.php?file=example-1.2.3-x64.exe">cross-origin-installer.exe</a>
<a href="https://example.test/rotation.php?file=example-1.2.3-x64.exe&amp;filename=other-1.2.3-x64.exe">Ambiguous wrapper</a>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://example.test/downloads.php' }
            }
        }

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'reject-unsafe-query-filename'
            Settings = [pscustomobject]@{ pageUri = 'https://example.test/downloads.php' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'NoReleasesFound'
        @($result.Releases).Count | Should -Be 0
        $parseEvent = @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryParsingCompleted')[-1]
        $parseEvent.Context.DownloadArtifactCandidateCount | Should -Be 0
    }
}

Describe 'Official download page explicit current-version metadata' {
    It 'associates nested Windows architecture downloads with an explicit Current Version field' {
        Mock Invoke-WebRequest -ModuleName 'Wintainium.provider.official-download-page' {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h2>Downloads</h2>
<h2>Current Version: 1.11.2</h2>
<h4>macOS</h4>
<a href="https://handbrake.fr/rotation.php?file=HandBrake-1.11.2-x86_64-Mac_GUI.dmg">Download macOS</a>
<h4>Windows</h4>
<p>For Windows 10 and later. Choose the processor type used by your PC:</p>
<h5>Intel or AMD (x64)</h5>
<a href="https://handbrake.fr/rotation.php?file=HandBrake-1.11.2-x86_64-Win_GUI.exe">Download installer (.exe)</a>
<a href="https://handbrake.fr/rotation.php?file=HandBrake-1.11.2-x86_64-Win_GUI.zip">Portable ZIP package</a>
<h5>Qualcomm (ARM64)</h5>
<a href="https://handbrake.fr/rotation.php?file=HandBrake-1.11.2-arm64-Win_GUI.exe">Download installer (.exe)</a>
<a href="https://handbrake.fr/rotation.php?file=HandBrake-1.11.2-arm64-Win_GUI.zip">Portable ZIP package</a>
<h4>Linux</h4>
<a href="https://handbrake.fr/rotation.php?file=HandBrake-1.11.2-x86_64-Linux.tar.gz">Linux archive</a>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://handbrake.fr/downloads.php' }
            }
        }

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'handbrake-current-version-nested-windows'
            Settings = [pscustomobject]@{ pageUri = 'https://handbrake.fr/downloads.php' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1

        $release = $result.Releases[0]
        $release.Version | Should -Be '1.11.2'
        @($release.Artifacts).Count | Should -Be 4
        @($release.Artifacts | Where-Object { $_.FileName -eq 'HandBrake-1.11.2-x86_64-Win_GUI.exe' -and $_.Architecture -eq 'x64' }).Count | Should -Be 1
        @($release.Artifacts | Where-Object { $_.FileName -eq 'HandBrake-1.11.2-x86_64-Win_GUI.zip' -and $_.Architecture -eq 'x64' }).Count | Should -Be 1
        @($release.Artifacts | Where-Object { $_.FileName -eq 'HandBrake-1.11.2-arm64-Win_GUI.exe' -and $_.Architecture -eq 'arm64' }).Count | Should -Be 1
        @($release.Artifacts | Where-Object { $_.FileName -eq 'HandBrake-1.11.2-arm64-Win_GUI.zip' -and $_.Architecture -eq 'arm64' }).Count | Should -Be 1
        @($release.Artifacts | Where-Object { $_.FileName -match 'Mac_GUI|Linux' }).Count | Should -Be 0

        $parseEvent = @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryParsingCompleted')[-1]
        $parseEvent.Context.Outcome | Should -Be 'ReleasesParsed'
        $parseEvent.Context.DownloadArtifactCandidateCount | Should -Be 4
        $parseEvent.Context.ParsedArtifactCount | Should -Be 4
    }
}

Describe 'SourceForge directory-download alias reconciliation' {
    It 'prefers the concrete file-row URL over a label-derived directory download' {
        Mock Invoke-WebRequest -ModuleName 'Wintainium.provider.official-download-page' {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h1>Peace Equalizer, interface Equalizer APO Files</h1>
<div class="release-version">1.6.9.11</div>
<a href="/projects/peace-equalizer-apo-extension/files/Peace/1.6.9.11/download">Download PeaceSetup.exe</a>
<table>
<tr><td><a href="/projects/peace-equalizer-apo-extension/files/PeaceSetup.exe/download">PeaceSetup.exe</a></td></tr>
<tr><td><a href="/projects/peace-equalizer-apo-extension/files/Peace.exe/download">Peace.exe</a></td></tr>
</table>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/' }
            }
        }

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'sourceforge-directory-alias-reconciliation'
            Settings = [pscustomobject]@{
                pageUri = 'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        @($result.Releases).Count | Should -Be 1
        $artifacts = @($result.Releases[0].Artifacts)
        $artifacts.Count | Should -Be 2
        @($artifacts | Where-Object FileName -eq 'PeaceSetup.exe').Count | Should -Be 1
        @($artifacts | Where-Object FileName -eq 'Peace.exe').Count | Should -Be 1
        (@($artifacts | Where-Object FileName -eq 'PeaceSetup.exe')[0]).Uri |
            Should -Be 'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/PeaceSetup.exe/download'
    }
}

Describe 'SourceForge latest-download alias reconciliation' {
    It 'prefers a concrete file-row URL when the latest-download alias identifies the same artifact' {
        Mock Invoke-WebRequest -ModuleName 'Wintainium.provider.official-download-page' {
            [pscustomobject]@{
                Content = @'
<html>
<body>
<h1>Peace Equalizer, interface Equalizer APO Files</h1>
<h2>Version 1.6.9.11</h2>
<a href="/projects/peace-equalizer-apo-extension/files/latest/download">Download Latest Version PeaceSetup.exe (55.7 MB)</a>
<table>
<tr><td><a href="/projects/peace-equalizer-apo-extension/files/PeaceSetup.exe/download">PeaceSetup.exe</a></td></tr>
<tr><td><a href="/projects/peace-equalizer-apo-extension/files/Peace.exe/download">Peace.exe</a></td></tr>
</table>
</body>
</html>
'@
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/' }
            }
        }

        $result = Invoke-WintainiumProviderReleaseDiscovery -Request ([pscustomobject]@{
            OperationId = 'sourceforge-latest-alias-reconciliation'
            Settings = [pscustomobject]@{
                pageUri = 'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1

        $artifacts = @($result.Releases[0].Artifacts)
        $artifacts.Count | Should -Be 2
        @($artifacts | Where-Object FileName -eq 'PeaceSetup.exe').Count | Should -Be 1
        @($artifacts | Where-Object FileName -eq 'Peace.exe').Count | Should -Be 1
        (@($artifacts | Where-Object FileName -eq 'PeaceSetup.exe')[0]).Uri |
            Should -Be 'https://sourceforge.net/projects/peace-equalizer-apo-extension/files/PeaceSetup.exe/download'

        $parseEvent = @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryParsingCompleted')[-1]
        $parseEvent.Context.ParsedReleaseCount | Should -Be 1
        $parseEvent.Context.ParsedArtifactCount | Should -Be 2
    }
}
