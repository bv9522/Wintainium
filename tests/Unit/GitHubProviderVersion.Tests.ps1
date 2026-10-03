BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:pluginPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.provider.github-releases/Wintainium.provider.github-releases.psm1'
    Import-Module $script:pluginPath -Force
}

Describe 'Wintainium GitHub release provider version normalization' {
    It 'normalizes prefixed GitHub release tags without discarding prerelease semantics' {
        Mock Invoke-RestMethod -ModuleName Wintainium.provider.github-releases {
            @(
                [pscustomobject]@{
                    id=401; tag_name='Audacity-4.0.1'; prerelease=$false; assets=@([pscustomobject]@{browser_download_url='https://example.test/a.exe';name='a.exe';size=1})
                },
                [pscustomobject]@{
                    id=379; tag_name='Audacity 3.7.9'; prerelease=$false; assets=@([pscustomobject]@{browser_download_url='https://example.test/b.exe';name='b.exe';size=1})
                },
                [pscustomobject]@{
                    id=404; tag_name='Audacity-4.0.0-beta-4'; prerelease=$true; assets=@([pscustomobject]@{browser_download_url='https://example.test/c.exe';name='c.exe';size=1})
                }
            )
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId='00000000-0000-0000-0000-000000000101'
            Settings=@{ repository='audacity/audacity'; maxPages=1 }
        })

        $result.IsSuccessful | Should -BeTrue
        ($result.Releases | Where-Object ReleaseId -eq '401').Version | Should -Be '4.0.1'
        ($result.Releases | Where-Object ReleaseId -eq '379').Version | Should -Be '3.7.9'
        ($result.Releases | Where-Object ReleaseId -eq '404').Version | Should -Be '4.0.0-beta-4'
    }

    It 'preserves a GitHub tag when it does not contain an unambiguous release version' {
        Mock Invoke-RestMethod -ModuleName Wintainium.provider.github-releases {
            @([pscustomobject]@{
                id=1; tag_name='release-latest-final'; prerelease=$false; assets=@([pscustomobject]@{browser_download_url='https://example.test/a.exe';name='a.exe';size=1})
            })
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId='00000000-0000-0000-0000-000000000102'
            Settings=@{ repository='example/project'; maxPages=1 }
        })

        $result.Releases[0].Version | Should -Be 'release-latest-final'
    }
}
