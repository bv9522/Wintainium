$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium download input boundary' {
    It 'accepts only an UpdateAvailable decision with a selected release and artifact' {
        $decision = [pscustomobject]@{
            Status = 'UpdateAvailable'
            IsUpdateAvailable = $true
            SelectedRelease = [pscustomobject]@{ ReleaseId = 'release-2'; Version = '2.0.0' }
            SelectedArtifact = [pscustomobject]@{ Uri = 'https://example.test/app.msi'; Format = 'msi'; Architecture = 'x64' }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Decision = $decision } {
            param($Decision)
            New-WintainiumDownloadRequest -UpdateDecision $Decision
        }

        $result.OperationId | Should -Not -BeNullOrEmpty
        $result.UpdateDecision | Should -Be $decision
        $result.SelectedRelease | Should -Be $decision.SelectedRelease
        $result.SelectedArtifact | Should -Be $decision.SelectedArtifact
    }

    It 'rejects a decision that does not indicate an available update' {
        $decision = [pscustomobject]@{
            Status = 'NoUpdateAvailable'
            IsUpdateAvailable = $false
            SelectedRelease = $null
            SelectedArtifact = $null
        }

        { InModuleScope Wintainium.Core -Parameters @{ Decision = $decision } {
                param($Decision)
                New-WintainiumDownloadRequest -UpdateDecision $Decision
            } } | Should -Throw
    }

    It 'rejects an update decision without a selected artifact' {
        $decision = [pscustomobject]@{
            Status = 'UpdateAvailable'
            IsUpdateAvailable = $true
            SelectedRelease = [pscustomobject]@{ ReleaseId = 'release-2'; Version = '2.0.0' }
            SelectedArtifact = $null
        }

        { InModuleScope Wintainium.Core -Parameters @{ Decision = $decision } {
                param($Decision)
                New-WintainiumDownloadRequest -UpdateDecision $Decision
            } } | Should -Throw
    }

    It 'does not invent or replace the selected artifact' {
        $artifact = [pscustomobject]@{ Uri = 'https://example.test/app.msi'; Format = 'msi'; Architecture = 'x64' }
        $decision = [pscustomobject]@{
            Status = 'UpdateAvailable'
            IsUpdateAvailable = $true
            SelectedRelease = [pscustomobject]@{ ReleaseId = 'release-2'; Version = '2.0.0' }
            SelectedArtifact = $artifact
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Decision = $decision } {
            param($Decision)
            New-WintainiumDownloadRequest -UpdateDecision $Decision
        }

        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app.msi'
        $result.PSObject.Properties.Name | Should -Contain 'UpdateDecision'
        $result.PSObject.Properties.Name | Should -Contain 'SelectedRelease'
        $result.PSObject.Properties.Name | Should -Contain 'SelectedArtifact'
    }

    It 'does not perform URI or destination validation at the input-boundary stage' {
        $decision = [pscustomobject]@{
            Status = 'UpdateAvailable'
            IsUpdateAvailable = $true
            SelectedRelease = [pscustomobject]@{ ReleaseId = 'release-2'; Version = '2.0.0' }
            SelectedArtifact = [pscustomobject]@{ Uri = 'not-a-uri'; FileName = '..\\..\\escape.exe' }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Decision = $decision } {
            param($Decision)
            New-WintainiumDownloadRequest -UpdateDecision $Decision
        }

        $result.SelectedArtifact.Uri | Should -Be 'not-a-uri'
        $result.SelectedArtifact.FileName | Should -Be '..\\..\\escape.exe'
    }
}
