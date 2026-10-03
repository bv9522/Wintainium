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
