BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:providerPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.provider.github-releases/Wintainium.provider.github-releases.psm1'
    Import-Module $script:providerPath -Force
}

Describe 'GitHub release asset verification evidence' {
    It 'projects GitHub release asset SHA256 digests into artifact hash claims' {
        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod {
            [pscustomobject]@{
                id = 2603
                tag_name = '26.03'
                prerelease = $false
                assets = @(
                    [pscustomobject]@{
                        browser_download_url = 'https://github.com/ip7z/7zip/releases/download/26.03/7z2603-x64.exe'
                        name = '7z2603-x64.exe'
                        size = 1650000
                        digest = 'sha256:0859c524b8a63551848f0c246abddcb1d0b7b656b0fbfe879f8d85e61a9e6edd'
                    }
                )
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            Settings = [pscustomobject]@{
                repository = 'ip7z/7zip'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        $artifact = $result.Releases[0].Artifacts[0]
        $artifact.Hashes.Count | Should -Be 1
        $artifact.Hashes[0].Algorithm | Should -Be 'SHA256'
        $artifact.Hashes[0].Value | Should -Be '0859C524B8A63551848F0C246ABDDA9D5E8863E0C84B7AC026BC9625A1560'
    }

    It 'fails open on discovery enrichment when GitHub provides no usable digest, leaving verification to Core' {
        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod {
            [pscustomobject]@{
                id = 1
                tag_name = '1.0.0'
                prerelease = $false
                assets = @(
                    [pscustomobject]@{
                        browser_download_url = 'https://github.com/example/app/releases/download/1.0.0/app.exe'
                        name = 'app.exe'
                        size = 10
                    }
                )
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            Settings = [pscustomobject]@{
                repository = 'example/app'
            }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Releases[0].Artifacts[0].Hashes.Count | Should -Be 0
    }
}
