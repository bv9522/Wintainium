$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium application install decision' {
    It 'selects the highest deterministic installable release when the application is not installed' {
        InModuleScope Wintainium.Core {
            $manifest = [pscustomobject]@{
                Id='example.app'
                Release=[pscustomobject]@{ channel='stable' }
                Artifact=[pscustomobject]@{ formats=@('exe'); architectures=@('x64'); allowUnknownArchitecture=$false }
            }
            $state = [pscustomobject]@{ ApplicationId='example.app'; InstallationState='NotInstalled' }
            $provider = [pscustomobject]@{
                IsSuccessful=$true
                Releases=@(
                    [pscustomobject]@{ ReleaseId='r1'; Version='1.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@([pscustomobject]@{Uri='https://example.test/one.exe';Format='exe';Architecture='x64'}) },
                    [pscustomobject]@{ ReleaseId='r2'; Version='2.0.0'; Channel='stable'; Deprecated=$false; Artifacts=@([pscustomobject]@{Uri='https://example.test/two.exe';Format='exe';Architecture='x64'}) }
                )
            }

            Mock Get-WintainiumEnvironment { [pscustomobject]@{ MachineArchitecture='x64' } }

            $result = Get-WintainiumApplicationInstallDecision -Manifest $manifest -InstalledState $state -ProviderResult $provider -MachineArchitecture x64

            $result.Status | Should -Be 'InstallAvailable'
            $result.IsInstallAvailable | Should -BeTrue
            $result.SelectedRelease.ReleaseId | Should -Be 'r2'
            $result.SelectedArtifact.Uri | Should -Be 'https://example.test/two.exe'
            $result.IsDeterministic | Should -BeTrue
        }
    }

    It 'does not offer installation for an already installed application' {
        InModuleScope Wintainium.Core {
            $manifest = [pscustomobject]@{ Id='example.app'; Release=[pscustomobject]@{channel='stable'} }
            $state = [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Installed'; Version='1.0.0' }
            $provider = [pscustomobject]@{ IsSuccessful=$true; Releases=@() }

            $result = Get-WintainiumApplicationInstallDecision -Manifest $manifest -InstalledState $state -ProviderResult $provider -MachineArchitecture x64

            $result.Status | Should -Be 'ApplicationAlreadyInstalled'
            $result.IsInstallAvailable | Should -BeFalse
        }
    }

    It 'does not guess when installed state is unknown' {
        InModuleScope Wintainium.Core {
            $manifest = [pscustomobject]@{ Id='example.app'; Release=[pscustomobject]@{channel='stable'} }
            $state = [pscustomobject]@{ ApplicationId='example.app'; InstallationState='Unknown' }
            $provider = [pscustomobject]@{ IsSuccessful=$true; Releases=@() }

            $result = Get-WintainiumApplicationInstallDecision -Manifest $manifest -InstalledState $state -ProviderResult $provider -MachineArchitecture x64

            $result.Status | Should -Be 'DecisionIndeterminate'
            $result.ReasonCode | Should -Be 'InstalledStateUnknown'
            $result.IsDeterministic | Should -BeFalse
        }
    }
}

Describe 'Wintainium public application install command' {
    It 'is exported from the Core module' {
        (Get-Command Invoke-WintainiumApplicationInstall -Module Wintainium.Core).CommandType | Should -Be 'Function'
    }

    It 'invokes the shared lifecycle in Install mode and preserves the public result projection' {
        InModuleScope Wintainium.Core {
            $lifecycle = [pscustomobject]@{
                OperationId='install-operation'
                IsSuccessful=$true
                WasCancelled=$false
                StageResults=@()
                Error=$null
            }
            $public = [pscustomobject]@{
                OperationId='install-operation'
                IsSuccessful=$true
                WasCancelled=$false
                Status='Completed'
                ApplicationId='example.app'
                Stages=@()
                Errors=@()
                Warnings=@()
                LogEvents=@()
                Error=$null
            }

            Mock Invoke-WintainiumApplicationUpdateLifecycle { $lifecycle }
            Mock ConvertTo-WintainiumPublicApplicationUpdateResult { $public }

            $result = Invoke-WintainiumApplicationInstall -ManifestPath 'C:example.wintainium.json' -StateRoot 'C:state' -MachineArchitecture x64 -DownloadRoot 'C:downloads'

            $result.OperationId | Should -Be 'install-operation'
            $result.Status | Should -Be 'Completed'
            Should -Invoke Invoke-WintainiumApplicationUpdateLifecycle -Times 1 -Exactly -ParameterFilter {
                $OperationKind -eq 'Install' -and
                $ManifestPath -eq 'C:example.wintainium.json' -and
                $StateRoot -eq 'C:state' -and
                $MachineArchitecture -eq 'x64' -and
                $DownloadRoot -eq 'C:downloads'
            }
            Should -Invoke ConvertTo-WintainiumPublicApplicationUpdateResult -Times 1 -Exactly
        }
    }
}


Describe 'Wintainium shared lifecycle install execution' {
    It 'uses the existing download, verification, installer, and reconciliation stages for a first install' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{
                Id='example.app'
                Source=[pscustomobject]@{pluginId='provider';requiredContractVersion='1';settings=@{}}
                Installer=[pscustomobject]@{pluginId='installer';requiredContractVersion='1';settings=@{}}
                Reconciliation=[pscustomobject]@{pluginId='reconciliation';requiredContractVersion='1';settings=@{}}
                Release=[pscustomobject]@{channel='stable'}
                Artifact=[pscustomobject]@{formats=@('exe');architectures=@('x64');allowUnknownArchitecture=$false}
            }
            $provider = [pscustomobject]@{PluginId='provider';PluginType='Provider'}
            $installer = [pscustomobject]@{PluginId='installer';PluginType='Installer'}
            $reconciliationPlugin = [pscustomobject]@{PluginId='reconciliation';PluginType='Reconciliation'}
            $release = [pscustomobject]@{OperationId=$operationId;IsSuccessful=$true;Status='DiscoveryCompleted';Releases=@([pscustomobject]@{ReleaseId='r1';Version='1.0.0';Channel='stable';Deprecated=$false;Artifacts=@([pscustomobject]@{Uri='https://example.test/app.exe';Format='exe';Architecture='x64'})});Errors=@();Warnings=@();LogEvents=@()}
            $decision = [pscustomobject]@{OperationId=$operationId;Status='InstallAvailable';IsInstallAvailable=$true;SelectedRelease=$release.Releases[0];SelectedArtifact=$release.Releases[0].Artifacts[0]}
            $download = [pscustomobject]@{OperationId=$operationId;Status='Downloaded';Uri='https://example.test/app.exe';FileName='app.exe';DestinationPath='C:downloadsapp.exe';BytesWritten=10}
            $verification = [pscustomobject]@{OperationId=$operationId;Status='Verified';Algorithm='SHA256';ExpectedHash=('a'*64);ActualHash=('a'*64);DestinationPath='C:downloadsapp.exe'}
            $selection = [pscustomobject]@{IsSelected=$true;InstallerPlugin=$installer;ArtifactFormat='exe'}
            $installation = [pscustomobject]@{OperationId=$operationId;Status='Completed';ExitCode=0}
            $reconciliationResult = [pscustomobject]@{OperationId=$operationId;IsSuccessful=$true;Status='Reconciled';Evidence=[pscustomobject]@{ApplicationId='example.app';InstallationState='Installed';Version='1.0.0';VersionSource='Fixture';Architecture='x64';Channel='stable';InstallationLocation='C:Program FilesExample';EvidenceSource='Fixture'};Errors=@();Warnings=@();LogEvents=@()}

            Mock New-WintainiumOrchestrationRequest { [pscustomobject]@{IsValid=$true;Request=[pscustomobject]@{OperationId=$operationId;ManifestPath='C:example.json';MachineArchitecture='x64';DownloadRoot='C:downloads'};Errors=@()} }
            Mock Test-WintainiumApplicationDefinition { [pscustomobject]@{OperationId=$operationId;IsValid=$true;Manifest=$manifest;ProviderPlugin=$provider;InstallerPlugin=$installer;ReconciliationPlugin=$reconciliationPlugin;Errors=@();Warnings=@();LogEvents=@()} }
            Mock Invoke-WintainiumProviderOperation { $release }
            Mock Get-WintainiumInstalledApplicationState { [pscustomobject]@{ApplicationId='example.app';InstallationState='NotInstalled'} }
            Mock Get-WintainiumApplicationInstallDecision { $decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{OperationId=$operationId;SelectedRelease=$decision.SelectedRelease;SelectedArtifact=$decision.SelectedArtifact} }
            Mock Invoke-WintainiumDownload { $download }
            Mock Invoke-WintainiumArtifactVerification { $verification }
            Mock Select-WintainiumInstaller { $selection }
            Mock New-WintainiumInstallerRequest { [pscustomobject]@{IsValid=$true;Request=[pscustomobject]@{OperationId=$operationId;DownloadOperationId=$operationId;Manifest=$manifest;Installer=$manifest.Installer;Artifact=[pscustomobject]@{Path='C:downloadsapp.exe';Uri='https://example.test/app.exe';FileName='app.exe'}};Errors=@()} }
            Mock New-WintainiumInstallerInvocation { [pscustomobject]@{IsValid=$true;Invocation=[pscustomobject]@{OperationId=$operationId;PluginId='installer';ArtifactPath='C:downloadsapp.exe';ArtifactFormat='exe';Settings=@{}};Error=$null} }
            Mock Invoke-WintainiumInstallerOperation { $installation }
            Mock Invoke-WintainiumReconciliationOperation { $reconciliationResult }
            Mock Invoke-WintainiumDownloadArtifactCleanup { [pscustomobject]@{IsSuccessful=$true;Status='Cleaned'} }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath 'C:example.json' -StateRoot 'C:state' -MachineArchitecture x64 -DownloadRoot 'C:downloads' -OperationKind Install

            $result.IsSuccessful | Should -BeTrue
            $result.State.Status | Should -Be 'Completed'
            @($result.StageResults).Count | Should -Be 8
            $result.StageResults[-1].Execution.Result.Evidence.InstallationState | Should -Be 'Installed'
            Should -Invoke Get-WintainiumApplicationInstallDecision -Times 1 -Exactly
            Should -Invoke Invoke-WintainiumDownload -Times 1 -Exactly
            Should -Invoke Invoke-WintainiumArtifactVerification -Times 1 -Exactly
            Should -Invoke Select-WintainiumInstaller -Times 1 -Exactly
            Should -Invoke Invoke-WintainiumInstallerOperation -Times 1 -Exactly
            Should -Invoke Invoke-WintainiumReconciliationOperation -Times 1 -Exactly
        }
    }
}
