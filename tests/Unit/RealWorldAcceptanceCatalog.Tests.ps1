BeforeAll {
    $script:catalogPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'RealWorld/real-world-applications.json'
    $script:catalog = @(Get-Content $script:catalogPath -Raw -Encoding utf8 | ConvertFrom-Json)
}

Describe 'Real-world acceptance catalog' {
    It 'contains at least 25 independently identified publisher applications' {
        $script:catalog.Count | Should -BeGreaterOrEqual 25
        @($script:catalog.id | Select-Object -Unique).Count | Should -Be $script:catalog.Count
    }

    It 'uses only supported live source families and absolute HTTPS URLs' {
        foreach ($app in $script:catalog) {
            $app.sourceFamily | Should -BeIn @('OfficialDownloadPage','GitHubReleases')
            $uri = [Uri]$app.sourceUri
            $uri.IsAbsoluteUri | Should -BeTrue
            $uri.Scheme | Should -Be 'https'
            $app.name | Should -Not -BeNullOrEmpty
        }
    }

    It 'contains meaningful coverage from both implemented source providers' {
        @($script:catalog | Where-Object sourceFamily -eq 'OfficialDownloadPage').Count | Should -BeGreaterOrEqual 10
        @($script:catalog | Where-Object sourceFamily -eq 'GitHubReleases').Count | Should -BeGreaterOrEqual 5
    }
}
