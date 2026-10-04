BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force
}

Describe 'Wintainium download artifact lifecycle cleanup' {
    It 'removes a completed operation artifact and its empty operation directory' {
        $root = Join-Path $TestDrive 'downloads'
        $operationDirectory = Join-Path $root 'operations/operation-1'
        New-Item -ItemType Directory -Path $operationDirectory -Force | Out-Null
        $artifactPath = Join-Path $operationDirectory 'app.msi'
        Set-Content -LiteralPath $artifactPath -Value 'artifact'

        $download = [pscustomobject]@{
            OperationId = 'operation-1'
            DestinationPath = $artifactPath
            ArtifactDirectory = $operationDirectory
            FileName = 'app.msi'
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Download=$download; Root=$root } {
            param($Download,$Root)
            Invoke-WintainiumDownloadArtifactCleanup -DownloadResult $Download -DownloadRoot $Root -Outcome Completed
        }

        $result.Status | Should -Be 'Removed'
        $result.Removed | Should -Be $true
        Test-Path -LiteralPath $artifactPath | Should -Be $false
        Test-Path -LiteralPath $operationDirectory | Should -Be $false
    }

    It 'retains a failed artifact with troubleshooting metadata' {
        $root = Join-Path $TestDrive 'downloads'
        $operationDirectory = Join-Path $root 'operations/operation-2'
        New-Item -ItemType Directory -Path $operationDirectory -Force | Out-Null
        $artifactPath = Join-Path $operationDirectory 'app.msi'
        Set-Content -LiteralPath $artifactPath -Value 'artifact'

        $download = [pscustomobject]@{
            OperationId = 'operation-2'
            DestinationPath = $artifactPath
            ArtifactDirectory = $operationDirectory
            FileName = 'app.msi'
            Uri = 'https://example.test/app.msi'
            FailureKind = 'VerificationMetadataMissing'
            ErrorMessage = 'Verification evidence was missing.'
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Download=$download; Root=$root } {
            param($Download,$Root)
            Invoke-WintainiumDownloadArtifactCleanup -DownloadResult $Download -DownloadRoot $Root -Outcome Failed
        }

        $result.Status | Should -Be 'Retained'
        $result.Retained | Should -Be $true
        Test-Path -LiteralPath $artifactPath | Should -Be $true
        Test-Path -LiteralPath (Join-Path $operationDirectory '.wintainium-artifact.json') | Should -Be $true
    }

    It 'purges failed operation directories older than the retention period' {
        $root = Join-Path $TestDrive 'downloads'
        $operationDirectory = Join-Path $root 'operations/old-operation'
        New-Item -ItemType Directory -Path $operationDirectory -Force | Out-Null
        $artifactPath = Join-Path $operationDirectory 'old.msi'
        Set-Content -LiteralPath $artifactPath -Value 'old artifact'
        [pscustomobject]@{
            SchemaVersion = '1.0'
            OperationId = 'old-operation'
            Outcome = 'Failed'
            RetainedAtUtc = [DateTime]::UtcNow.AddDays(-30).ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $operationDirectory '.wintainium-artifact.json')

        $currentDirectory = Join-Path $root 'operations/current-operation'
        New-Item -ItemType Directory -Path $currentDirectory -Force | Out-Null
        $currentArtifact = Join-Path $currentDirectory 'current.msi'
        Set-Content -LiteralPath $currentArtifact -Value 'current artifact'

        $download = [pscustomobject]@{
            OperationId = 'current-operation'
            DestinationPath = $currentArtifact
            ArtifactDirectory = $currentDirectory
            FileName = 'current.msi'
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Download=$download; Root=$root } {
            param($Download,$Root)
            Invoke-WintainiumDownloadArtifactCleanup -DownloadResult $Download -DownloadRoot $Root -Outcome Failed -RetentionDays 7
        }

        $result.PurgedOperations | Should -Contain $operationDirectory
        Test-Path -LiteralPath $operationDirectory | Should -Be $false
        Test-Path -LiteralPath $currentArtifact | Should -Be $true
    }

    It 'purges legacy installer artifacts directly under the Core-owned download root' {
        $root = Join-Path $TestDrive 'downloads'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $legacyArtifact = Join-Path $root '7z2408-x64.exe'
        Set-Content -LiteralPath $legacyArtifact -Value 'legacy artifact'

        $currentDirectory = Join-Path $root 'operations/current-operation'
        New-Item -ItemType Directory -Path $currentDirectory -Force | Out-Null
        $currentArtifact = Join-Path $currentDirectory 'current.msi'
        Set-Content -LiteralPath $currentArtifact -Value 'current artifact'

        $download = [pscustomobject]@{
            OperationId = 'current-operation'
            DestinationPath = $currentArtifact
            ArtifactDirectory = $currentDirectory
            FileName = 'current.msi'
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Download=$download; Root=$root } {
            param($Download,$Root)
            Invoke-WintainiumDownloadArtifactCleanup -DownloadResult $Download -DownloadRoot $Root -Outcome Failed
        }

        $result.PurgedLegacyArtifacts | Should -Contain $legacyArtifact
        Test-Path -LiteralPath $legacyArtifact | Should -Be $false
        Test-Path -LiteralPath $currentArtifact | Should -Be $true
    }
}