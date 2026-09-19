Describe 'Wintainium public application update command boundary' {
    BeforeAll {
        $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
        Import-Module $script:modulePath -Force
    }

    AfterAll {
        Remove-Module -Name Wintainium.Core -Force -ErrorAction SilentlyContinue
    }

    It 'forwards the documented public inputs to the Core lifecycle without exposing internal dependencies' {
        InModuleScope Wintainium.Core {
            $captured = $null
            Mock Invoke-WintainiumApplicationUpdateLifecycle {
                $captured = [pscustomobject][ordered]@{
                    ManifestPath=$ManifestPath
                    StateRoot=$StateRoot
                    MachineArchitecture=$MachineArchitecture
                    DownloadRoot=$DownloadRoot
                    PluginRoot=$PluginRoot
                    SchemaPath=$SchemaPath
                    InstallerTimeoutMilliseconds=$InstallerTimeoutMilliseconds
                    CancellationToken=$CancellationToken
                }

                [pscustomobject][ordered]@{
                    OperationId='operation-10c-inputs'
                    IsSuccessful=$true
                    WasCancelled=$false
                    StageResults=@()
                    Error=$null
                }
            }

            $tokenSource = [System.Threading.CancellationTokenSource]::new()
            $result = Invoke-WintainiumApplicationUpdate -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json' -StateRoot 'C:\Wintainium\State' -MachineArchitecture 'x64' -DownloadRoot 'C:\Wintainium\Downloads' -PluginRoot 'C:\Wintainium\Plugins' -SchemaPath 'C:\Wintainium\schemas\application-manifest.schema.json' -InstallerTimeoutMilliseconds 120000 -CancellationToken $tokenSource.Token

            $result.Status | Should -Be 'Completed'
            $captured.ManifestPath | Should -Be 'C:\Wintainium\manifests\Example.wintainium.json'
            $captured.StateRoot | Should -Be 'C:\Wintainium\State'
            $captured.MachineArchitecture | Should -Be 'x64'
            $captured.DownloadRoot | Should -Be 'C:\Wintainium\Downloads'
            $captured.PluginRoot | Should -Be 'C:\Wintainium\Plugins'
            $captured.SchemaPath | Should -Be 'C:\Wintainium\schemas\application-manifest.schema.json'
            $captured.InstallerTimeoutMilliseconds | Should -Be 120000
            $captured.CancellationToken.Equals($tokenSource.Token) | Should -BeTrue
            Should -Invoke Invoke-WintainiumApplicationUpdateLifecycle -Times 1 -Exactly
        }
    }

    It 'uses the documented default timeout when the caller omits it' {
        InModuleScope Wintainium.Core {
            $capturedTimeout = $null
            Mock Invoke-WintainiumApplicationUpdateLifecycle {
                $capturedTimeout = $InstallerTimeoutMilliseconds
                [pscustomobject][ordered]@{
                    OperationId='operation-10c-default-timeout'
                    IsSuccessful=$true
                    WasCancelled=$false
                    StageResults=@()
                    Error=$null
                }
            }

            Invoke-WintainiumApplicationUpdate -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json' -StateRoot 'C:\Wintainium\State' -MachineArchitecture 'x64' -DownloadRoot 'C:\Wintainium\Downloads' | Out-Null

            $capturedTimeout | Should -Be 600000
        }
    }

    It 'does not accept internal orchestration inputs at the public command boundary' {
        $command = Get-Command -Name Invoke-WintainiumApplicationUpdate -CommandType Function

        $command.Parameters.Keys | Should -Not -Contain 'StagePlan'
        $command.Parameters.Keys | Should -Not -Contain 'StageFactory'
        $command.Parameters.Keys | Should -Not -Contain 'CancellationContext'
        $command.Parameters.Keys | Should -Not -Contain 'HttpClient'
        $command.Parameters.Keys | Should -Not -Contain 'ProviderRequest'
        $command.Parameters.Keys | Should -Not -Contain 'DownloadRequest'
        $command.Parameters.Keys | Should -Not -Contain 'InstallerRequest'
        $command.Parameters.Keys | Should -Not -Contain 'ReconciliationRequest'
    }

    It 'returns the public projection even when the lifecycle supplies internal state and request objects' {
        InModuleScope Wintainium.Core {
            Mock Invoke-WintainiumApplicationUpdateLifecycle {
                [pscustomobject][ordered]@{
                    OperationId='operation-10c-projection'
                    IsSuccessful=$false
                    WasCancelled=$false
                    State=[pscustomobject]@{ Status='Failed'; Internal='secret' }
                    Request=[pscustomobject]@{ ManifestPath='secret' }
                    StageResults=@(
                        [pscustomobject]@{
                            Stage=[pscustomobject]@{ Sequence=1; Name='ManifestValidation' }
                            Execution=[pscustomobject]@{
                                IsSuccessful=$false
                                WasCancelled=$false
                                Result=[pscustomobject]@{
                                    IsSuccessful=$false
                                    Status='ValidationFailed'
                                    Manifest=[pscustomobject]@{ Id='example.app' }
                                    Error=[pscustomobject]@{ Code='ManifestValidationFailed'; Message='Invalid manifest.' }
                                    Errors=@([pscustomobject]@{ Code='ManifestValidationFailed'; Message='Invalid manifest.' })
                                    Warnings=@()
                                    LogEvents=@()
                                    InternalRequest='secret'
                                }
                                InternalDependency='secret'
                            }
                        }
                    )
                    Error=[pscustomobject]@{ Code='ManifestValidationFailed'; Message='Invalid manifest.' }
                }
            }

            $result = Invoke-WintainiumApplicationUpdate -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json' -StateRoot 'C:\Wintainium\State' -MachineArchitecture 'x64' -DownloadRoot 'C:\Wintainium\Downloads'

            $result.Status | Should -Be 'Failed'
            $result.ApplicationId | Should -Be 'example.app'
            $result.Stages[0].Error.Code | Should -Be 'ManifestValidationFailed'
            $result.PSObject.Properties.Name | Should -Not -Contain 'State'
            $result.PSObject.Properties.Name | Should -Not -Contain 'Request'
            $result.Stages[0].PSObject.Properties.Name | Should -Not -Contain 'InternalDependency'
            $result.Stages[0].PSObject.Properties.Name | Should -Not -Contain 'InternalRequest'
        }
    }
}
