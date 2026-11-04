BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:providerPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.provider.github-releases/Wintainium.provider.github-releases.psm1'
    Import-Module $script:providerPath -Force
}

Describe 'Wintainium GitHub source resolution' {
    It 'resolves a repository URL to canonical repository identity' {
        $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
            OperationId = 'github-source-1'
            SourceUri = 'https://github.com/PCSX2/pcsx2'
        })

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Resolved'
        $result.OperationId | Should -Be 'github-source-1'
        $result.Source.ApplicationId | Should -Be 'github.pcsx2.pcsx2'
        $result.Source.Name | Should -Be 'pcsx2'
        $result.Source.Publisher | Should -Be 'PCSX2'
        $result.Source.Homepage | Should -Be 'https://github.com/PCSX2/pcsx2'
        $result.Source.CanonicalUri | Should -Be 'https://github.com/PCSX2/pcsx2'
        $result.Source.ProviderId | Should -Be 'Wintainium.provider.github-releases'
        $result.Source.ProviderContractVersion | Should -Be '1'
        $result.Source.ProviderSettings.repository | Should -Be 'PCSX2/pcsx2'
        $result.Source.SourceContext.repository | Should -Be 'PCSX2/pcsx2'
        $result.Source.SourceContext.PSObject.Properties.Name | Should -Not -Contain 'releaseTag'
    }

    It 'normalizes the www host and .git repository suffix' {
        $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
            OperationId = 'github-source-2'
            SourceUri = 'https://www.github.com/microsoft/PowerToys.git'
        })

        $result.IsSuccessful | Should -Be $true
        $result.Source.CanonicalUri | Should -Be 'https://github.com/microsoft/PowerToys'
        $result.Source.ProviderSettings.repository | Should -Be 'microsoft/PowerToys'
    }

    It 'resolves a releases collection URL without inventing release context' {
        $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
            OperationId = 'github-source-3'
            SourceUri = 'https://github.com/PCSX2/pcsx2/releases'
        })

        $result.IsSuccessful | Should -Be $true
        $result.Source.ProviderSettings.repository | Should -Be 'PCSX2/pcsx2'
        $result.Source.SourceContext.repository | Should -Be 'PCSX2/pcsx2'
        $result.Source.SourceContext.PSObject.Properties.Name | Should -Not -Contain 'releaseTag'
    }

    It 'preserves a releases collection URL for navigation while retaining repository identity' {
        $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
            OperationId = 'github-source-release-homepage'
            SourceUri = 'https://github.com/PCSX2/pcsx2/releases'
        })

        $result.IsSuccessful | Should -BeTrue
        $result.Source.Homepage | Should -Be 'https://github.com/PCSX2/pcsx2/releases'
        $result.Source.CanonicalUri | Should -Be 'https://github.com/PCSX2/pcsx2'
        $result.Source.ProviderSettings.repository | Should -Be 'PCSX2/pcsx2'
    }

    It 'resolves a release tag URL and preserves the exact tag' {
        $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
            OperationId = 'github-source-4'
            SourceUri = 'https://github.com/ValveSoftware/Proton/releases/tag/proton-10.0-4'
        })

        $result.IsSuccessful | Should -Be $true
        $result.Source.ProviderSettings.repository | Should -Be 'ValveSoftware/Proton'
        $result.Source.SourceContext.repository | Should -Be 'ValveSoftware/Proton'
        $result.Source.SourceContext.releaseTag | Should -Be 'proton-10.0-4'
    }

    It 'resolves source identity locally without requiring GitHub access' {
        $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
            OperationId = 'github-source-5'
            SourceUri = 'https://github.com/yt-dlp/yt-dlp/releases/tag/2026.01.01'
        })

        $result.IsSuccessful | Should -Be $true
        $result.Status | Should -Be 'Resolved'
        $result.Source.ProviderSettings.repository | Should -Be 'yt-dlp/yt-dlp'
    }

    It 'maintains normalized identity across a 100-case repository URL stress matrix' {
        $caseCount = 0
        for ($ownerIndex = 1; $ownerIndex -le 10; $ownerIndex++) {
            for ($repositoryIndex = 1; $repositoryIndex -le 10; $repositoryIndex++) {
                $owner = 'Publisher{0:D2}' -f $ownerIndex
                $repository = 'Application{0:D2}' -f $repositoryIndex
                $caseVariant = $caseCount % 4
                $sourceUri = switch ($caseVariant) {
                    0 { "https://github.com/$owner/$repository" }
                    1 { "https://www.github.com/$owner/$repository.git" }
                    2 { "https://github.com/$owner/$repository/releases" }
                    3 { "https://github.com/$owner/$repository/releases/tag/v1.2.3" }
                }

                $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
                    OperationId = "identity-matrix-$caseCount"
                    SourceUri = $sourceUri
                })

                $result.IsSuccessful | Should -BeTrue -Because "case $caseCount should resolve '$sourceUri'"
                $result.Status | Should -Be 'Resolved'
                $result.OperationId | Should -Be "identity-matrix-$caseCount"
                $result.Source.ApplicationId | Should -Be "github.$($owner.ToLowerInvariant()).$($repository.ToLowerInvariant())"
                $result.Source.CanonicalUri | Should -Be "https://github.com/$owner/$repository"
                $result.Source.ProviderSettings.repository | Should -Be "$owner/$repository"
                $result.Source.SourceContext.repository | Should -Be "$owner/$repository"
                $result.Source.ProviderId | Should -Be 'Wintainium.provider.github-releases'
                $result.Source.ProviderContractVersion | Should -Be '1'

                if ($caseVariant -eq 3) {
                    $result.Source.SourceContext.releaseTag | Should -Be 'v1.2.3'
                }
                else {
                    $result.Source.SourceContext.PSObject.Properties.Name | Should -Not -Contain 'releaseTag'
                }

                $caseCount++
            }
        }

        $caseCount | Should -Be 100
    }

    It 'rejects a non-GitHub host' {
        $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
            OperationId = 'github-source-6'
            SourceUri = 'https://gitlab.com/example/project'
        })

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceUnsupported'
        @($result.Errors.Code) | Should -Contain 'GitHubSourceHostUnsupported'
    }

    It 'rejects GitHub paths that do not identify a repository' {
        $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
            OperationId = 'github-source-7'
            SourceUri = 'https://github.com/settings/profile'
        })

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceUnsupported'
        @($result.Errors.Code) | Should -Contain 'GitHubRepositoryPathInvalid'
    }

    It 'rejects an invalid source URI' {
        $result = Invoke-WintainiumProviderSourceResolution -Request ([pscustomobject]@{
            OperationId = 'github-source-8'
            SourceUri = 'not-a-uri'
        })

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'SourceUnsupported'
        @($result.Errors.Code) | Should -Contain 'GitHubSourceHostUnsupported'
    }
}
