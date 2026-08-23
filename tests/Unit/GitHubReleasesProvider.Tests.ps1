BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:providerPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.provider.github-releases/Wintainium.provider.github-releases.psm1'

    Import-Module $script:providerPath -Force
}

Describe 'Wintainium GitHub Releases provider' {
    It 'rejects a missing repository setting without network access' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000101'
            Settings = @{}
        }

        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod { throw 'Network access should not occur.' }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ConfigurationInvalid'
        @($result.Errors.Code) | Should -Contain 'GitHubRepositoryMissing'
        Should -Invoke Invoke-RestMethod -ModuleName Wintainium.provider.github-releases -Times 0 -Exactly
    }

    It 'rejects an invalid repository setting without network access' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000106'
            Settings = @{ repository = 'example/project/extra' }
        }

        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod { throw 'Network access should not occur.' }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ConfigurationInvalid'
        @($result.Errors.Code) | Should -Contain 'GitHubRepositoryInvalid'
        Should -Invoke Invoke-RestMethod -ModuleName Wintainium.provider.github-releases -Times 0 -Exactly
    }

    It 'maps GitHub releases and assets into normalized Wintainium data' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000102'
            Settings = @{ repository = 'example/project' }
        }

        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod {
            @(
                [pscustomobject]@{
                    id = 123
                    tag_name = 'v2.4.0'
                    prerelease = $false
                    published_at = '2026-08-01T12:00:00Z'
                    assets = @(
                        [pscustomobject]@{
                            browser_download_url = 'https://github.com/example/project/releases/download/v2.4.0/example-2.4.0-x64.zip'
                            name = 'example-2.4.0-x64.zip'
                            size = 1024
                        },
                        [pscustomobject]@{
                            browser_download_url = 'https://github.com/example/project/releases/download/v2.4.0/example-2.4.0-arm64.msi'
                            name = 'example-2.4.0-arm64.msi'
                            size = 2048
                        }
                    )
                },
                [pscustomobject]@{
                    id = 122
                    tag_name = 'v2.3.0-beta1'
                    prerelease = $true
                    published_at = '2026-07-01T12:00:00Z'
                    assets = @()
                }
            )
        }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        $result.Releases | Should -HaveCount 2
        $result.Releases[0].ReleaseId | Should -Be '123'
        $result.Releases[0].Version | Should -Be 'v2.4.0'
        $result.Releases[0].Channel | Should -Be 'stable'
        $result.Releases[0].Artifacts | Should -HaveCount 2
        $result.Releases[0].Artifacts[0].Format | Should -Be 'zip'
        $result.Releases[0].Artifacts[0].Architecture | Should -Be 'x64'
        $result.Releases[0].Artifacts[1].Format | Should -Be 'msi'
        $result.Releases[0].Artifacts[1].Architecture | Should -Be 'arm64'
        $result.Releases[1].Channel | Should -Be 'prerelease'
        $result.Releases[1].Artifacts | Should -HaveCount 0
        Should -Invoke Invoke-RestMethod -ModuleName Wintainium.provider.github-releases -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://api.github.com/repos/example/project/releases?per_page=100&page=1'
        }
    }

    It 'paginates when GitHub returns a full page and stops on the first short page' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000107'
            Settings = @{ repository = 'example/project'; maxPages = 3 }
        }

        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod {
            if ($Uri -like '*page=1') {
                return @(1..100 | ForEach-Object {
                    [pscustomobject]@{
                        id = $_
                        tag_name = "v1.0.$_"
                        prerelease = $false
                        published_at = $null
                        assets = @()
                    }
                })
            }

            return @(
                [pscustomobject]@{
                    id = 101
                    tag_name = 'v1.0.101'
                    prerelease = $false
                    published_at = $null
                    assets = @()
                }
            )
        }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        $result.Releases | Should -HaveCount 101
        $result.Releases[100].ReleaseId | Should -Be '101'
        Should -Invoke Invoke-RestMethod -ModuleName Wintainium.provider.github-releases -Times 2 -Exactly
    }

    It 'returns NoReleasesFound for an empty GitHub releases collection' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000103'
            Settings = @{ repository = 'example/project' }
        }

        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod { $null }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'NoReleasesFound'
        @($result.Releases) | Should -HaveCount 0
        @($result.Errors) | Should -HaveCount 0
    }

    It 'returns SourceNotFound for a GitHub repository that does not exist' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000104'
            Settings = @{ repository = 'example/missing-project' }
        }

        $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
        $exception = [System.Net.Http.HttpRequestException]::new('Not Found')
        $exception.Data['StatusCode'] = 404

        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod { throw $exception }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'SourceNotFound'
        @($result.Errors.Code) | Should -Contain 'GitHubRepositoryNotFound'
    }

    It 'rejects malformed GitHub release data as an upstream response failure' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000108'
            Settings = @{ repository = 'example/project' }
        }

        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod {
            @([pscustomobject]@{
                id = 200
                tag_name = 'v2.5.0'
                prerelease = $false
                published_at = 'not-a-timestamp'
                assets = @()
            })
        }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'UpstreamResponseInvalid'
        @($result.Errors.Code) | Should -Contain 'GitHubReleaseInvalid'
    }

    It 'rejects malformed GitHub asset data as an upstream response failure' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000109'
            Settings = @{ repository = 'example/project' }
        }

        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod {
            @([pscustomobject]@{
                id = 201
                tag_name = 'v2.5.1'
                prerelease = $false
                published_at = $null
                assets = @([pscustomobject]@{
                    browser_download_url = 'https://github.com/example/project/releases/download/v2.5.1/example.zip'
                    size = 1024
                })
            })
        }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'UpstreamResponseInvalid'
        @($result.Errors.Code) | Should -Contain 'GitHubReleaseInvalid'
    }

    It 'rejects a non-HTTPS GitHub asset URL as an upstream response failure' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000110'
            Settings = @{ repository = 'example/project' }
        }

        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod {
            @([pscustomobject]@{
                id = 202
                tag_name = 'v2.5.2'
                prerelease = $false
                published_at = $null
                assets = @([pscustomobject]@{
                    browser_download_url = 'http://example.invalid/example.zip'
                    name = 'example.zip'
                    size = 1024
                })
            })
        }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'UpstreamResponseInvalid'
        @($result.Errors.Code) | Should -Contain 'GitHubReleaseInvalid'
    }

    It 'rejects invalid maxPages configuration' {
        $request = [pscustomobject]@{
            OperationId = '00000000-0000-0000-0000-000000000105'
            Settings = @{ repository = 'example/project'; maxPages = 0 }
        }

        Mock -ModuleName Wintainium.provider.github-releases Invoke-RestMethod { throw 'Network access should not occur.' }

        $result = Invoke-WintainiumProvider -Request $request

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ConfigurationInvalid'
        @($result.Errors.Code) | Should -Contain 'GitHubMaxPagesInvalid'
        Should -Invoke Invoke-RestMethod -ModuleName Wintainium.provider.github-releases -Times 0 -Exactly
    }
}
