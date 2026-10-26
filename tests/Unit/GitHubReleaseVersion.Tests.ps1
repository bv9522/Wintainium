BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:providerPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.provider.github-releases/Wintainium.provider.github-releases.psm1'
    Import-Module $script:providerPath -Force
}

Describe 'Wintainium GitHub release tag version normalization' {
    It 'extracts a stable version from a release/v-prefixed tag' {
        Mock Invoke-RestMethod -ModuleName Wintainium.provider.github-releases {
            [pscustomobject]@{
                id = 293
                tag_name = 'release/v2.9.3'
                prerelease = $false
                assets = @()
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = 'github-version-release-prefix'
            Settings = [pscustomobject]@{ repository = 'windirstat/windirstat' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        $result.Releases.Count | Should -Be 1
        $result.Releases[0].Version | Should -Be '2.9.3'
        $result.Releases[0].Channel | Should -Be 'stable'
    }

    It 'extracts a stable version from a simple v-prefixed tag' {
        Mock Invoke-RestMethod -ModuleName Wintainium.provider.github-releases {
            [pscustomobject]@{
                id = 270
                tag_name = 'v2.7.0'
                prerelease = $false
                assets = @()
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = 'github-version-v-prefix'
            Settings = [pscustomobject]@{ repository = 'example/example' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Releases[0].Version | Should -Be '2.7.0'
        $result.Releases[0].Channel | Should -Be 'stable'
    }

    It 'does not classify a beta tag with a date suffix as a stable release' {
        Mock Invoke-RestMethod -ModuleName Wintainium.provider.github-releases {
            [pscustomobject]@{
                id = 291
                tag_name = 'beta/v2.9.1/2026-10-04'
                prerelease = $true
                assets = @()
            }
        }

        $result = Invoke-WintainiumProvider -Request ([pscustomobject]@{
            OperationId = 'github-version-beta-tag'
            Settings = [pscustomobject]@{ repository = 'example/example' }
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Releases[0].Channel | Should -Be 'prerelease'
        $result.Releases[0].Version | Should -Be 'beta/v2.9.1/2026-10-04'
    }
}
