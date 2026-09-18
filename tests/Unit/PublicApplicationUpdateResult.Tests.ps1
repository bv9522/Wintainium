$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium public application update result' {
    It 'projects a successful lifecycle into the stable public result shape' {
        InModuleScope Wintainium.Core {
            $operationId = [guid]::NewGuid().ToString()
            $manifest = [pscustomobject]@{ Id='example.app' }
            $lifecycle = [pscustomobject][ordered]@{
                OperationId=$operationId
                IsSuccessful=$true
                WasCancelled=$false
                StageResults=@(
                    [pscustomobject]@{
                        Stage=[pscustomobject]@{ Sequence=1; Name='ManifestValidation' }
                        Execution=[pscustomobject]@{
                            IsSuccessful=$true
                            WasCancelled=$false
                            Result=[pscustomobject]@{ IsSuccessful=$true; Status='Validated'; Manifest=$manifest; Errors=@(); Warnings=@(); LogEvents=@() }
                        }
                    },
                    [pscustomobject]@{
                        Stage=[pscustomobject]@{ Sequence=2; Name='ReleaseDiscovery' }
                        Execution=[pscustomobject]@{
                            IsSuccessful=$true
                            WasCancelled=$false
                            Result=[pscustomobject]@{ IsSuccessful=$true; Status='DiscoveryCompleted'; Errors=@(); Warnings=@(); LogEvents=@() }
                        }
                    }
                )
                Error=$null
            }

            $result = ConvertTo-WintainiumPublicApplicationUpdateResult -LifecycleResult $lifecycle

            $result.OperationId | Should -Be $operationId
            $result.IsSuccessful | Should -BeTrue
            $result.WasCancelled | Should -BeFalse
            $result.Status | Should -Be 'Completed'
            $result.ApplicationId | Should -Be 'example.app'
            @($result.Stages).Count | Should -Be 2
            $result.Stages[0].Name | Should -Be 'ManifestValidation'
            $result.Stages[0].Status | Should -Be 'Validated'
            @($result.Errors).Count | Should -Be 0
        }
    }

    It 'projects cancellation as Cancelled without changing the internal lifecycle state vocabulary' {
        InModuleScope Wintainium.Core {
            $lifecycle = [pscustomobject][ordered]@{
                OperationId=[guid]::NewGuid().ToString()
                IsSuccessful=$false
                WasCancelled=$true
                StageResults=@()
                Error=[pscustomobject]@{ Code='OrchestrationWorkflowCancelled'; Message='Cancelled.' }
            }

            $result = ConvertTo-WintainiumPublicApplicationUpdateResult -LifecycleResult $lifecycle

            $result.Status | Should -Be 'Cancelled'
            $result.WasCancelled | Should -BeTrue
            $result.IsSuccessful | Should -BeFalse
            @($result.Stages).Count | Should -Be 0
            $result.Error.Code | Should -Be 'OrchestrationWorkflowCancelled'
            @($result.Errors).Count | Should -Be 1
        }
    }

    It 'projects failure as Failed and preserves structured terminal errors' {
        InModuleScope Wintainium.Core {
            $lifecycle = [pscustomobject][ordered]@{
                OperationId=[guid]::NewGuid().ToString()
                IsSuccessful=$false
                WasCancelled=$false
                StageResults=@()
                Error=[pscustomobject]@{ Code='ProviderDiscoveryFailed'; Message='Provider failed.' }
            }

            $result = ConvertTo-WintainiumPublicApplicationUpdateResult -LifecycleResult $lifecycle

            $result.Status | Should -Be 'Failed'
            $result.IsSuccessful | Should -BeFalse
            $result.Error.Code | Should -Be 'ProviderDiscoveryFailed'
            @($result.Errors).Count | Should -Be 1
        }
    }
}
