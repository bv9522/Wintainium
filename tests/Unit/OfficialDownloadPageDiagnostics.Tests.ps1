BeforeAll {
    $script:repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:providerPath = Join-Path $script:repoRoot 'plugins/Wintainium.provider.official-download-page/Wintainium.provider.official-download-page.psm1'
    Import-Module $script:providerPath -Force
}

Describe 'Official download page discovery diagnostics' {
    BeforeEach {
        $script:request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000101'
            ApplicationId = 'example.application'
            ProviderId = 'Wintainium.provider.official-download-page'
            Settings = @{ pageUri = 'https://example.test/downloads?token=do-not-log-this' }
            DiscoveryContext = @{}
        }
    }

    It 'distinguishes an unrecognized release page from retrieval failure and redacts URL query data' {
        Mock Invoke-WebRequest -ModuleName 'Wintainium.provider.official-download-page' {
            [pscustomobject]@{
                Content = '<html><head><title>Example downloads</title></head><body><p>Welcome</p></body></html>'
                Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://example.test/final-downloads?session=also-secret' }
            }
        }

        $result = Invoke-WintainiumProvider -Request $script:request
        $trace = @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryParsingCompleted')
        $serialized = ConvertTo-Json -InputObject $result -Depth 12

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'NoReleasesFound'
        @($result.Releases).Count | Should -Be 0
        $trace.Count | Should -Be 1
        $trace[0].Context.Outcome | Should -Be 'NoReleaseSectionCandidates'
        $trace[0].Context.HttpStatusCode | Should -Be 200
        $trace[0].Context.FinalUrl | Should -Be 'https://example.test/final-downloads'
        $serialized | Should -Not -Match 'do-not-log-this|also-secret'
    }

    It 'recognizes plain-text release labels with alphabetic version suffixes' {
        Mock Invoke-WebRequest -ModuleName 'Wintainium.provider.official-download-page' {
            [pscustomobject]@{
                Content = '<html><body><div class="release-title">Release 11.50a</div><p>24 September 2026 / Windows 10 and 11 / 64-bit only</p><a href="/ac-11_50a.exe">Full setup</a><a href="/ac-11_50a-portable.exe">Portable</a><div class="release-title">Release 11.40b</div><a href="/ac-11_40b.exe">Older setup</a></body></html>'
                Headers = @{ 'Content-Type' = 'text/html' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://example.test/downloads' }
            }
        }

        $result = Invoke-WintainiumProvider -Request $script:request
        $trace = @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryParsingCompleted')

        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 2
        $result.Releases[0].Version | Should -Be '11.50a'
        @($result.Releases[0].Artifacts).Count | Should -Be 2
        $result.Releases[0].Artifacts[0].Architecture | Should -Be 'x64'
        $result.Releases[0].Artifacts[1].Architecture | Should -Be 'x64'
        $result.Releases[1].Version | Should -Be '11.40b'
        $result.Releases[1].Artifacts[0].Architecture | Should -Be 'unknown'
        $trace[0].Context.Outcome | Should -Be 'ReleasesParsed'
    }

    It 'records recognized release and artifact counts when parsing succeeds' {
        Mock Invoke-WebRequest -ModuleName 'Wintainium.provider.official-download-page' {
            [pscustomobject]@{
                Content = '<html><body><h2>Version 1.2.3</h2><a href="/downloads/example-1.2.3-x64.zip">Download ZIP</a></body></html>'
                Headers = @{ 'Content-Type' = 'text/html' }
                StatusCode = 200
                BaseResponse = [pscustomobject]@{ ResponseUri = [Uri]'https://example.test/downloads' }
            }
        }

        $result = Invoke-WintainiumProvider -Request $script:request
        $trace = @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryParsingCompleted')

        $result.Status | Should -Be 'Success'
        @($result.Releases).Count | Should -Be 1
        @($result.Releases[0].Artifacts).Count | Should -Be 1
        $trace[0].Context.SectionCandidateCount | Should -Be 1
        $trace[0].Context.DownloadArtifactCandidateCount | Should -Be 1
        $trace[0].Context.ParsedReleaseCount | Should -Be 1
        $trace[0].Context.Outcome | Should -Be 'ReleasesParsed'
    }

    It 'records GitHub as an intentional provider fallback without exposing URL query data' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000102'
            SourceUri = 'https://github.com/example/project?token=do-not-log-this'
        }

        $result = Invoke-WintainiumProviderSourceResolution -Request $request
        $serialized = ConvertTo-Json -InputObject $result -Depth 12

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'SourceUnsupported'
        @($result.LogEvents | Where-Object EventName -eq 'SourceResolutionDelegated').Count | Should -Be 1
        $serialized | Should -Not -Match 'do-not-log-this'
    }

    It 'returns a sanitized retrieval failure without logging the signed query string' {
        Mock Invoke-WebRequest -ModuleName 'Wintainium.provider.official-download-page' {
            throw [System.Net.WebException]::new('Request failed for https://example.test/downloads?token=do-not-log-this')
        }

        $result = Invoke-WintainiumProvider -Request $script:request
        $serialized = ConvertTo-Json -InputObject $result -Depth 12

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'SourceUnavailable'
        @($result.LogEvents | Where-Object EventName -eq 'ReleaseDiscoveryRetrievalFailed').Count | Should -Be 1
        $serialized | Should -Not -Match 'do-not-log-this'
    }
}
