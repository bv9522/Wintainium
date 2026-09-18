$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium application update lifecycle failure matrix' {
    BeforeEach {
        $script:operationId = [guid]::NewGuid().ToString()
        $script:manifest = [pscustomobject]@{
            Id = 'example.app'
            Source = [pscustomobject]@{ pluginId='Wintainium.provider.valid-fixture'; requiredContractVersion='1'; settings=@{} }
            Installer = [pscustomobject]@{ pluginId='Wintainium.installer.valid-fixture'; requiredContractVersion='1'; settings=@{} }
            Reconciliation = [pscustomobject]@{ pluginId='Wintainium.reconciliation.valid-fixture'; requiredContractVersion='1'; settings=@{} }
            Release = [pscustomobject]@{ channel='stable' }
            Artifact = [pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false }
        }
        $script:provider = [pscustomobject]@{ PluginId='Wintainium.provider.valid-fixture'; PluginType='Provider' }
        $script:installer = [pscustomobject]@{ PluginId='Wintainium.installer.valid-fixture'; PluginType='Installer' }
        $script:reconciliation = [pscustomobject]@{ PluginId='Wintainium.reconciliation.valid-fixture'; PluginType='Reconciliation' }
        $script:release = [pscustomobject]@{
            OperationId=$script:operationId
            IsSuccessful=$true
            Status='DiscoveryCompleted'
            Releases=@([pscustomobject]@{
                ReleaseId='release-2'; Version='2.0.0'; Channel='stable'; Deprecated=$false
                Artifacts=@([pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64'; Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('a'*64) }) })
            })
            Errors=@(); Warnings=@(); LogEvents=@()
        }
        $script:decision = [pscustomobject]@{ OperationId=$script:operationId; Status='UpdateAvailable'; IsUpdateAvailable=$true; SelectedRelease=$script:release.Releases[0]; SelectedArtifact=$script:release.Releases[0].Artifacts[0] }

        Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$script:operationId; IsValid=$true; Manifest=$script:manifest; ProviderPlugin=$script:provider; InstallerPlugin=$script:installer; ReconciliationPlugin=$script:reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
        Mock Select-WintainiumInstaller { throw 'installer selection must not execute before download succeeds' }
        Mock New-WintainiumInstallerRequest { throw 'installer request must not execute after upstream failure' }
        Mock New-WintainiumInstallerInvocation { throw 'installer invocation must not execute after upstream failure' }
        Mock Invoke-WintainiumInstallerOperation { throw 'installer must not execute after upstream failure' }
        Mock Invoke-WintainiumReconciliationOperation { throw 'reconciliation must not execute after upstream failure' }
    }

    It 'blocks update execution when provider discovery fails' {
        InModuleScope Wintainium.Core {
            Mock Invoke-WintainiumProviderOperation {
                [pscustomobject]@{
                    OperationId=$script:operationId; IsSuccessful=$false; Status='DiscoveryFailed'
                    Errors=@([pscustomobject]@{ Code='ProviderDiscoveryFailed'; Message='Provider fixture failure.' })
                    Warnings=@(); LogEvents=@()
                }
            }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeFalse
            $result.State.Status | Should -Be 'Failed'
            $result.State.FailedStage.Name | Should -Be 'ReleaseDiscovery'
            @($result.StageResults).Count | Should -Be 2
            $result.StageResults[-1].Execution.Result.Status | Should -Be 'DiscoveryFailed'
            $result.StageResults[-1].Execution.Result.IsSuccessful | Should -BeFalse
            Should -Invoke Invoke-WintainiumProviderOperation -Times 1 -Exactly -ParameterFilter { $Request.OperationId -eq $script:operationId }
            Should -Invoke Invoke-WintainiumArtifactVerification -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumInstallerOperation -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 0 -Exactly
        }
    }

    It 'blocks verification, installation, and reconciliation when download fails' {
        InModuleScope Wintainium.Core {
            Mock Invoke-WintainiumProviderOperation { $script:release }
            Mock Invoke-WintainiumDownload {
                [pscustomobject]@{
                    OperationId=$script:operationId; IsSuccessful=$false; Status='Failed'
                    FailureKind='DownloadFailed'; ErrorMessage='Download fixture failure.'
                }
            }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'

            $result.IsSuccessful | Should -BeFalse
            $result.State.Status | Should -Be 'Failed'
            $result.State.FailedStage.Name | Should -Be 'Download'
            @($result.StageResults).Count | Should -Be 4
            $result.StageResults[-1].Execution.Result.Status | Should -Be 'Failed'
            $result.StageResults[-1].Execution.Result.FailureKind | Should -Be 'DownloadFailed'
            Should -Invoke Invoke-WintainiumProviderOperation -Times 1 -Exactly
            Should -Invoke New-WintainiumDownloadRequest -Times 1 -Exactly -ParameterFilter { $OperationId -eq $script:operationId }
            Should -Invoke Invoke-WintainiumArtifactVerification -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumInstallerOperation -Times 0 -Exactly
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 0 -Exactly
        }
    }
}
