$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium application update lifecycle extended failure boundaries' {
    It 'blocks reconciliation when installation fails' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{ Id='example.app'; Source=[pscustomobject]@{ pluginId='Wintainium.provider.valid-fixture'; requiredContractVersion='1'; settings=@{} }; Installer=[pscustomobject]@{ pluginId='Wintainium.installer.valid-fixture'; requiredContractVersion='1'; settings=@{} }; Reconciliation=[pscustomobject]@{ pluginId='Wintainium.reconciliation.valid-fixture'; requiredContractVersion='1'; settings=@{} }; Release=[pscustomobject]@{ channel='stable' }; Artifact=[pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false } }
            $provider=[pscustomobject]@{ PluginId='Wintainium.provider.valid-fixture'; PluginType='Provider' }
            $installer=[pscustomobject]@{ PluginId='Wintainium.installer.valid-fixture'; PluginType='Installer' }
            $reconciliation=[pscustomobject]@{ PluginId='Wintainium.reconciliation.valid-fixture'; PluginType='Reconciliation' }
            $release=[pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='DiscoveryCompleted'; Releases=@([pscustomobject]@{ ReleaseId='release-2'; Version='2.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@([pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64' }) }); Errors=@(); Warnings=@(); LogEvents=@() }
            $decision=[pscustomobject]@{ OperationId=$operationId; Status='UpdateAvailable'; IsUpdateAvailable=$true; SelectedRelease=$release.Releases[0]; SelectedArtifact=$release.Releases[0].Artifacts[0] }
            $download=[pscustomobject]@{ OperationId=$operationId; Status='Downloaded'; Uri='https://example.test/app.exe'; FileName='app.exe'; DestinationPath='/tmp/app.exe'; BytesWritten=10 }
            $verification=[pscustomobject]@{ OperationId=$operationId; Status='Verified'; Algorithm='SHA256'; ExpectedHash='a'*64; ActualHash='a'*64; DestinationPath='/tmp/app.exe' }
            $selection=[pscustomobject]@{ IsSelected=$true; InstallerPlugin=$installer; ArtifactFormat='exe' }
            $installerRequest=[pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId }; Errors=@() }
            $invocation=[pscustomobject]@{ IsValid=$true; Invocation=[pscustomobject]@{ OperationId=$operationId }; Error=$null }
            $installation=[pscustomobject]@{ OperationId=$operationId; Status='Failed'; IsSuccessful=$false; FailureKind='InstallerFailed'; ErrorMessage='Fixture installer failed.' }
            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$operationId; IsValid=$true; Manifest=$manifest; ProviderPlugin=$provider; InstallerPlugin=$installer; ReconciliationPlugin=$reconciliation; Errors=@(); Warnings=@(); LogEvents=@() } }
            Mock Invoke-WintainiumProviderOperation { $release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0' } }
            Mock Get-WintainiumUpdateDecision { $decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$operationId } }
            Mock Invoke-WintainiumDownload { $download }
            Mock Invoke-WintainiumArtifactVerification { $verification }
            Mock Select-WintainiumInstaller { $selection }
            Mock New-WintainiumInstallerRequest { $installerRequest }
            Mock New-WintainiumInstallerInvocation { $invocation }
            Mock Invoke-WintainiumInstallerOperation { $installation }
            Mock Invoke-WintainiumReconciliationOperation { throw 'reconciliation must not execute after installer failure' }
            Mock Set-WintainiumInstalledApplicationState { throw 'state persistence must not execute after installer failure' }
            $result=Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'
            $result.IsSuccessful | Should -BeFalse; $result.State.Status | Should -Be 'Failed'; $result.State.FailedStage.Name | Should -Be 'Installation'; $result.StageResults[-1].StageName | Should -Be 'Installation'; $result.StageResults[-1].Execution.Result.FailureKind | Should -Be 'InstallerFailed'; @($result.StageResults).Count | Should -Be 7
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 0 -Exactly; Should -Invoke Set-WintainiumInstalledApplicationState -Times 0 -Exactly
        }
    }

    It 'blocks authoritative persistence when reconciliation fails' {
        InModuleScope Wintainium.Core {
            $operationId=[guid]::NewGuid().ToString(); $manifest=[pscustomobject]@{ Id='example.app'; Source=[pscustomobject]@{ pluginId='Wintainium.provider.valid-fixture'; requiredContractVersion='1'; settings=@{} }; Installer=[pscustomobject]@{ pluginId='Wintainium.installer.valid-fixture'; requiredContractVersion='1'; settings=@{} }; Reconciliation=[pscustomobject]@{ pluginId='Wintainium.reconciliation.valid-fixture'; requiredContractVersion='1'; settings=@{} }; Release=[pscustomobject]@{ channel='stable' }; Artifact=[pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false } }; $provider=[pscustomobject]@{ PluginId='Wintainium.provider.valid-fixture'; PluginType='Provider' }; $installer=[pscustomobject]@{ PluginId='Wintainium.installer.valid-fixture'; PluginType='Installer' }; $reconciliationPlugin=[pscustomobject]@{ PluginId='Wintainium.reconciliation.valid-fixture'; PluginType='Reconciliation' }; $release=[pscustomobject]@{ OperationId=$operationId; IsSuccessful=$true; Status='DiscoveryCompleted'; Releases=@([pscustomobject]@{ ReleaseId='release-2'; Version='2.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@([pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64' }) }); Errors=@(); Warnings=@(); LogEvents=@() }; $decision=[pscustomobject]@{ OperationId=$operationId; Status='UpdateAvailable'; IsUpdateAvailable=$true; SelectedRelease=$release.Releases[0]; SelectedArtifact=$release.Releases[0].Artifacts[0] }; $download=[pscustomobject]@{ OperationId=$operationId; Status='Downloaded'; Uri='https://example.test/app.exe'; FileName='app.exe'; DestinationPath='/tmp/app.exe'; BytesWritten=10 }; $verification=[pscustomobject]@{ OperationId=$operationId; Status='Verified'; Algorithm='SHA256'; ExpectedHash='a'*64; ActualHash='a'*64; DestinationPath='/tmp/app.exe' }; $selection=[pscustomobject]@{ IsSelected=$true; InstallerPlugin=$installer; ArtifactFormat='exe' }; $installerRequest=[pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId }; Errors=@() }; $invocation=[pscustomobject]@{ IsValid=$true; Invocation=[pscustomobject]@{ OperationId=$operationId }; Error=$null }; $installation=[pscustomobject]@{ OperationId=$operationId; Status='Completed'; IsSuccessful=$true }; $reconciliation=[pscustomobject]@{ OperationId=$operationId; IsSuccessful=$false; Status='Unknown'; Evidence=$null; Errors=@([pscustomobject]@{ Code='ReconciliationFailed'; Message='Fixture reconciliation failed.' }); Warnings=@(); LogEvents=@() }
            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{ IsValid=$true; Request=[pscustomobject]@{ OperationId=$operationId; ManifestPath='/tmp/example.json'; MachineArchitecture='x64'; DownloadRoot='/tmp/downloads' }; Errors=@() } }; Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{ OperationId=$operationId; IsValid=$true; Manifest=$manifest; ProviderPlugin=$provider; InstallerPlugin=$installer; ReconciliationPlugin=$reconciliationPlugin; Errors=@(); Warnings=@(); LogEvents=@() } }; Mock Invoke-WintainiumProviderOperation { $release }; Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0' } }; Mock Get-WintainiumUpdateDecision { $decision }; Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId=$operationId } }; Mock Invoke-WintainiumDownload { $download }; Mock Invoke-WintainiumArtifactVerification { $verification }; Mock Select-WintainiumInstaller { $selection }; Mock New-WintainiumInstallerRequest { $installerRequest }; Mock New-WintainiumInstallerInvocation { $invocation }; Mock Invoke-WintainiumInstallerOperation { $installation }; Mock Invoke-WintainiumReconciliationOperation { $reconciliation }; Mock Set-WintainiumInstalledApplicationState { throw 'state persistence must not execute after reconciliation failure' }
            $result=Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads'
            $result.IsSuccessful | Should -BeFalse; $result.State.Status | Should -Be 'Failed'; $result.State.FailedStage.Name | Should -Be 'Reconciliation'; $result.StageResults[-1].StageName | Should -Be 'Reconciliation'; $result.StageResults[-1].Execution.Result.Errors[0].Code | Should -Be 'ReconciliationFailed'; @($result.StageResults).Count | Should -Be 8; Should -Invoke Set-WintainiumInstalledApplicationState -Times 0 -Exactly
        }
    }

    It 'propagates pre-cancelled lifecycle without executing update stages or persisting state' {
        InModuleScope Wintainium.Core {
            $cts=[System.Threading.CancellationTokenSource]::new()
            try {
                $cts.Cancel()
                Mock Test-WintainiumApplicationDefinition { throw 'manifest validation must not execute after cancellation' }
                Mock Get-WintainiumInstalledApplicationState { throw 'installed-state lookup must not execute after cancellation' }
                Mock Set-WintainiumInstalledApplicationState { throw 'state persistence must not execute after cancellation' }
                $result=Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath '/tmp/example.json' -StateRoot '/tmp/state' -MachineArchitecture x64 -DownloadRoot '/tmp/downloads' -CancellationToken $cts.Token
                $result.IsSuccessful | Should -BeFalse
                $result.WasCancelled | Should -BeTrue
                $result.State.Status | Should -Be 'Pending'
                $result.State.PSObject.Properties['Cancelled'] | Should -BeNullOrEmpty
                Should -Invoke Test-WintainiumApplicationDefinition -Times 0 -Exactly
                Should -Invoke Get-WintainiumInstalledApplicationState -Times 0 -Exactly
                Should -Invoke Set-WintainiumInstalledApplicationState -Times 0 -Exactly
            } finally { $cts.Dispose() }
        }
    }
}
