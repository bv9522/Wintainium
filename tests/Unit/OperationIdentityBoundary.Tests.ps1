$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium lifecycle OperationId request boundaries' {
    It 'preserves a supplied OperationId in download requests' {
        $operationId = [guid]::NewGuid().ToString()
        $decision = [pscustomobject]@{
            Status = 'UpdateAvailable'
            IsUpdateAvailable = $true
            SelectedRelease = [pscustomobject]@{ ReleaseId='release-2'; Version='2.0.0' }
            SelectedArtifact = [pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64' }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Decision=$decision; OperationId=$operationId } {
            param($Decision,$OperationId)
            New-WintainiumDownloadRequest -UpdateDecision $Decision -OperationId $OperationId
        }

        $result.OperationId | Should -Be $operationId
    }

    It 'rejects an invalid supplied OperationId in download requests' {
        $decision = [pscustomobject]@{
            Status = 'UpdateAvailable'
            IsUpdateAvailable = $true
            SelectedRelease = [pscustomobject]@{ ReleaseId='release-2'; Version='2.0.0' }
            SelectedArtifact = [pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64' }
        }

        { InModuleScope Wintainium.Core -Parameters @{ Decision=$decision } {
            param($Decision)
            New-WintainiumDownloadRequest -UpdateDecision $Decision -OperationId 'not-a-guid'
        } } | Should -Throw
    }

    It 'preserves a supplied OperationId in installer requests' {
        $operationId = [guid]::NewGuid().ToString()
        $artifactPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wintainium-operation-id-{0}.msi" -f [guid]::NewGuid())
        [System.IO.File]::WriteAllText($artifactPath, 'fixture')
        try {
            $manifest = [pscustomobject]@{
                Id='example.app'
                Installer=[pscustomobject]@{ pluginId='Wintainium.installer.msi'; requiredContractVersion='1'; settings=[pscustomobject]@{} }
                artifact=[pscustomobject]@{ formats=@('msi'); architectures=@('x64') }
            }
            $download = [pscustomobject]@{
                OperationId=([guid]::NewGuid()).ToString()
                Status='Downloaded'
                Uri='https://example.test/example.msi'
                FileName='example.msi'
                DestinationPath=$artifactPath
                BytesWritten=7
            }

            $result = InModuleScope Wintainium.Core -Parameters @{ Download=$download; Manifest=$manifest; OperationId=$operationId } {
                param($Download,$Manifest,$OperationId)
                New-WintainiumInstallerRequest -DownloadResult $Download -Manifest $Manifest -OperationId $OperationId
            }

            $result.IsValid | Should -BeTrue
            $result.Request.OperationId | Should -Be $operationId
            $result.Request.DownloadOperationId | Should -Be $download.OperationId
        }
        finally {
            if (Test-Path -LiteralPath $artifactPath) { Remove-Item -LiteralPath $artifactPath -Force }
        }
    }

    It 'rejects an invalid supplied OperationId in installer requests' {
        $artifactPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wintainium-operation-id-{0}.msi" -f [guid]::NewGuid())
        [System.IO.File]::WriteAllText($artifactPath, 'fixture')
        try {
            $manifest = [pscustomobject]@{
                Id='example.app'
                Installer=[pscustomobject]@{ pluginId='Wintainium.installer.msi'; requiredContractVersion='1'; settings=[pscustomobject]@{} }
                artifact=[pscustomobject]@{ formats=@('msi'); architectures=@('x64') }
            }
            $download = [pscustomobject]@{ OperationId=([guid]::NewGuid()).ToString(); Status='Downloaded'; Uri='https://example.test/example.msi'; FileName='example.msi'; DestinationPath=$artifactPath; BytesWritten=7 }

            $result = InModuleScope Wintainium.Core -Parameters @{ Download=$download; Manifest=$manifest } {
                param($Download,$Manifest)
                New-WintainiumInstallerRequest -DownloadResult $Download -Manifest $Manifest -OperationId 'not-a-guid'
            }

            $result.IsValid | Should -BeFalse
            $result.Errors.Code | Should -Contain 'OperationIdInvalid'
        }
        finally {
            if (Test-Path -LiteralPath $artifactPath) { Remove-Item -LiteralPath $artifactPath -Force }
        }
    }
}
