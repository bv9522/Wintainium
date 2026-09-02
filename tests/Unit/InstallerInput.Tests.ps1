$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium installer input boundary' {
    BeforeEach {
        $artifactPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wintainium-installer-input-{0}.bin" -f [guid]::NewGuid())
        [System.IO.File]::WriteAllText($artifactPath, 'fixture')

        $manifest = [pscustomobject]@{
            Id = 'example.app'
            Installer = [pscustomobject]@{
                pluginId = 'Wintainium.installer.msi'
                requiredContractVersion = '1'
                settings = [pscustomobject]@{}
            }
            artifact = [pscustomobject]@{
                formats = @('msi')
                architectures = @('x64')
            }
        }

        $downloadResult = [pscustomobject]@{
            OperationId = ([guid]::NewGuid()).ToString()
            Status = 'Downloaded'
            FailureKind = $null
            Uri = 'https://example.test/example.msi'
            FileName = 'example.msi'
            DestinationPath = $artifactPath
            BytesWritten = 7
            Retryable = $false
            ErrorMessage = $null
        }
    }

    AfterEach {
        if (Test-Path -LiteralPath $artifactPath) {
            Remove-Item -LiteralPath $artifactPath -Force
        }
    }

    It 'accepts a completed download and a valid installer reference' {
        $result = New-WintainiumInstallerRequest -DownloadResult $downloadResult -Manifest $manifest

        $result.IsValid | Should -BeTrue
        $result.Errors.Count | Should -Be 0
        $result.Request | Should -Not -BeNullOrEmpty
    }

    It 'creates a new installer operation identifier and preserves the download correlation identifier' {
        $result = New-WintainiumInstallerRequest -DownloadResult $downloadResult -Manifest $manifest

        $result.Request.OperationId | Should -Not -Be $downloadResult.OperationId
        $result.Request.OperationId | Should -Not -BeNullOrEmpty
        $result.Request.DownloadOperationId | Should -Be $downloadResult.OperationId
    }

    It 'preserves the validated manifest and installer reference' {
        $result = New-WintainiumInstallerRequest -DownloadResult $downloadResult -Manifest $manifest

        $result.Request.Manifest | Should -Be $manifest
        $result.Request.Installer | Should -Be $manifest.Installer
    }

    It 'derives the installer artifact path from the completed download result' {
        $result = New-WintainiumInstallerRequest -DownloadResult $downloadResult -Manifest $manifest

        $result.Request.Artifact.Path | Should -Be $downloadResult.DestinationPath
        $result.Request.Artifact.FileName | Should -Be $downloadResult.FileName
        $result.Request.Artifact.Uri | Should -Be $downloadResult.Uri
    }

    It 'rejects a download that has not completed' {
        $downloadResult.Status = 'Failed'

        $result = New-WintainiumInstallerRequest -DownloadResult $downloadResult -Manifest $manifest

        $result.IsValid | Should -BeFalse
        $result.Request | Should -BeNullOrEmpty
        $result.Errors.Code | Should -Contain 'InstallerInputDownloadNotCompleted'
    }

    It 'rejects a missing downloaded artifact' {
        Remove-Item -LiteralPath $artifactPath -Force

        $result = New-WintainiumInstallerRequest -DownloadResult $downloadResult -Manifest $manifest

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'InstallerInputArtifactMissing'
    }

    It 'rejects a relative downloaded artifact path' {
        $downloadResult.DestinationPath = 'relative\\example.msi'

        $result = New-WintainiumInstallerRequest -DownloadResult $downloadResult -Manifest $manifest

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'InstallerInputArtifactPathNotAbsolute'
    }

    It 'rejects a manifest without an installer reference' {
        $manifest.Installer = $null

        $result = New-WintainiumInstallerRequest -DownloadResult $downloadResult -Manifest $manifest

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'InstallerInputManifestInstallerMissing'
    }

    It 'rejects a non-installer plugin identifier' {
        $manifest.Installer.pluginId = 'Wintainium.provider.github-releases'

        $result = New-WintainiumInstallerRequest -DownloadResult $downloadResult -Manifest $manifest

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'InstallerInputManifestInstallerIdInvalid'
    }

    It 'does not perform trust verification or execute the downloaded artifact' {
        $result = New-WintainiumInstallerRequest -DownloadResult $downloadResult -Manifest $manifest

        $result.Request.PSObject.Properties.Name | Should -Not -Contain 'IsTrusted'
        $result.Request.PSObject.Properties.Name | Should -Not -Contain 'VerificationResult'
        $result.Request.PSObject.Properties.Name | Should -Not -Contain 'ExitCode'
    }
}
