$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium application update lifecycle failure boundaries' {
    It 'blocks installation and reconciliation when artifact verification fails' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{
                Id = 'example.app'
                Source = [pscustomobject]@{ pluginId='Wintainium.provider.valid-fixture'; requiredContractVersion='1'; settings=@{} }
                Installer = [pscustomobject]@{ pluginId='Wintainium.installer.valid-fixture'; requiredContractVersion='1'; settings=@{} }
                Reconciliation = [pscustomobject]@{ pluginId='Wintainium.reconciliation.valid-fixture'; requiredContractVersion='1'; settings=@{} }
                Release = [pscustomobject]@{ channel='stable' }
                Artifact = [pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false }
            }
            $provider = [pscustomobject]@{ PluginId='Wintainium.provider.valid-fixture'; PluginType='Provider' }
            $installer = [pscustomobject]@{ PluginId='Wintainium.installer.valid-fixture'; PluginType='Installer' }
            $reconciliation = [pscustomobject]@{ PluginId='Wintainium.reconciliation.valid-fixture'; PluginType='Reconciliation' }
            $release = [pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='DiscoveryCompleted'; Releases=@([pscustomobject]@{ ReleaseId='release-2'; Version='2.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@([pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64'; Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('a'*64) }) }) }); Errors=@(); Warnings=@(); LogEvents=@() }
            $decision = [pscustomobject]@{ OperationId=$operationId; Status='UpdateAvailable'; IsUpdateAvailable=$true; SelectedRelease=$release.Releases[0]; SelectedArtifact=$release.Releases[0].Artifacts[0] }
            $download = [pscustomobject]@{ OperationId=$operationId; Status='Downloaded'; Uri='https://example.test/app.exe'; FileName='app.exe'; DestinationPath='/tmp/app.exe'; BytesWritten=10 }
            $verification = [pscustomobject]@{ OperationId=$operationId; Status='Failed'; FailureKind='HashMismatch'; DestinationPath='/tmp/app.exe'; ErrorMessage='Artifact hash does not match the expected SHA-256 value.' }
            $selection = [pscustomobject]@{ IsSelected=$true; InstallerPlugin=$installer; ArtifactFormat='exe' }

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$operationId; IsValid=$true; Manifest=$manifest; ProviderPlugin=$provider; InstallerPlugin=$installer; ReconciliationPlugin=$reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0'; VersionSource='Fixture'; Architecture='x64'; Channel='stable'; InstallationLocation='/opt/example' } }
            Mock Get-WintainiumUpdateDecision { $decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$operationId; UpdateDecision=$decision; SelectedRelease=$decision.SelectedRelease; SelectedArtifact=$decision.SelectedArtifact } }
            Mock Invoke-WintainiumDownload { $download }
            Mock Invoke-WintainiumArtifactVerification { $verification }
            Mock Select-WintainiumInstaller { $selection }
            Mock New-WintainiumInstallerRequest { throw 'installer request must not execute after verification failure' }
            Mock New-WintainiumInstallerInvocation { throw 'installer invocation must not execute after verification failure' }
            Mock Invoke-WintainiumInstallerOperation { throw 'installer must not execute after verification failure' }
            Mock Invoke-WintainiumReconciliationOperation { throw 'reconciliation must not execute after verification failure' }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeFalse
            $result.State.Status | Should -Be 'Failed'
            $result.State.FailedStage.Name | Should -Be 'Verification'
            $result.Error.Code | Should -Be 'OrchestrationStageExecutionFailed'
            $result.StageResults[-1].StageName | Should -Be 'Verification'
            $result.StageResults[-1].Execution.Result.Status | Should -Be 'Failed'
            $result.StageResults[-1].Execution.Result.FailureKind | Should -Be 'HashMismatch'
            @($result.StageResults).Count | Should -Be 5
            Should -Invoke Invoke-WintainiumInstallerOperation -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 0 -Exactly
            Should -Invoke New-WintainiumInstallerRequest -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumArtifactVerification -Times 1 -Exactly -ParameterFilter { $OperationId -eq $operationId }
        }
    }
}
