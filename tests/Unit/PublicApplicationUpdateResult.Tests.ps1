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
    It 'exposes exactly the documented top-level properties and preserves empty collections as arrays' {
        InModuleScope Wintainium.Core {
            $lifecycle = [pscustomobject][ordered]@{
                OperationId=[guid]::NewGuid().ToString()
                IsSuccessful=$true
                WasCancelled=$false
                StageResults=@()
                Error=$null
            }

            $result = ConvertTo-WintainiumPublicApplicationUpdateResult -LifecycleResult $lifecycle

            @($result.PSObject.Properties.Name) | Should -Be @(
                'OperationId'
                'IsSuccessful'
                'WasCancelled'
                'Status'
                'ApplicationId'
                'Stages'
                'Errors'
                'Warnings'
                'LogEvents'
                'Error'
            )
            $result.Status | Should -Be 'Completed'
            $result.Stages.GetType().Name | Should -Be 'Object[]'
            $result.Errors.GetType().Name | Should -Be 'Object[]'
            $result.Warnings.GetType().Name | Should -Be 'Object[]'
            $result.LogEvents.GetType().Name | Should -Be 'Object[]'
        }
    }

    It 'maps lifecycle state to the stable public status vocabulary' {
        InModuleScope Wintainium.Core {
            $cases = @(
                [pscustomobject]@{ IsSuccessful=$true; WasCancelled=$false; Expected='Completed' }
                [pscustomobject]@{ IsSuccessful=$false; WasCancelled=$false; Expected='Failed' }
                [pscustomobject]@{ IsSuccessful=$true; WasCancelled=$true; Expected='Cancelled' }
                [pscustomobject]@{ IsSuccessful=$false; WasCancelled=$true; Expected='Cancelled' }
            )

            foreach ($case in $cases) {
                $lifecycle = [pscustomobject][ordered]@{
                    OperationId=[guid]::NewGuid().ToString()
                    IsSuccessful=$case.IsSuccessful
                    WasCancelled=$case.WasCancelled
                    StageResults=@()
                    Error=$null
                }

                $result = ConvertTo-WintainiumPublicApplicationUpdateResult -LifecycleResult $lifecycle

                $result.Status | Should -Be $case.Expected
            }
        }
    }

    It 'exposes exactly the documented stage summary properties and decision diagnostics' {
        InModuleScope Wintainium.Core {
            $lifecycle = [pscustomobject][ordered]@{
                OperationId=[guid]::NewGuid().ToString()
                IsSuccessful=$true
                WasCancelled=$false
                StageResults=@(
                    [pscustomobject]@{
                        Stage=[pscustomobject]@{ Sequence=1; Name='ManifestValidation'; InternalOnly='secret' }
                        Execution=[pscustomobject]@{
                            IsSuccessful=$true
                            WasCancelled=$false
                            Result=[pscustomobject]@{ IsSuccessful=$true; Status='Validated'; Errors=@(); Warnings=@(); LogEvents=@() }
                            InternalOnly='secret'
                        }
                    },
                    [pscustomobject]@{
                        Stage=[pscustomobject]@{ Sequence=3; Name='UpdateDecision'; InternalOnly='secret' }
                        Execution=[pscustomobject]@{
                            IsSuccessful=$true
                            WasCancelled=$false
                            Result=[pscustomobject]@{ IsSuccessful=$true; Status='DecisionIndeterminate'; ReasonCode='ApplicationNotInstalled'; Reason='The application is not installed.'; Errors=@(); Warnings=@(); LogEvents=@() }
                            InternalOnly='secret'
                        }
                    }
                )
                Error=$null
                InternalState='secret'
            }

            $result = ConvertTo-WintainiumPublicApplicationUpdateResult -LifecycleResult $lifecycle

            @($result.Stages[0].PSObject.Properties.Name) | Should -Be @(
                'Sequence'
                'Name'
                'Status'
                'ReasonCode'
                'Reason'
                'IsSuccessful'
                'WasCancelled'
                'Error'
            )
            $result.Stages[1].ReasonCode | Should -Be 'ApplicationNotInstalled'
            $result.Stages[1].Reason | Should -Be 'The application is not installed.'
        }
    }

    It 'preserves stage-operation sequence numbers and surfaces structured stage failures' {
        InModuleScope Wintainium.Core {
            $lifecycle = [pscustomobject][ordered]@{
                OperationId=[guid]::NewGuid().ToString()
                IsSuccessful=$false
                WasCancelled=$false
                StageResults=@(
                    [pscustomobject]@{
                        StageSequence=1
                        StageName='ManifestValidation'
                        Execution=[pscustomobject]@{
                            IsSuccessful=$true
                            WasCancelled=$false
                            Result=[pscustomobject]@{ IsSuccessful=$true; Status='Validated'; Errors=@(); Warnings=@(); LogEvents=@() }
                        }
                    },
                    [pscustomobject]@{
                        StageSequence=4
                        StageName='Download'
                        Execution=[pscustomobject]@{
                            IsSuccessful=$false
                            WasCancelled=$false
                            Result=[pscustomobject]@{
                                IsSuccessful=$false
                                Status='Failed'
                                FailureKind='Network'
                                ErrorMessage='The remote server returned an error.'
                            }
                            Error=[pscustomobject]@{
                                Code='OrchestrationStageStructuredFailure'
                                Message='The remote server returned an error.'
                            }
                        }
                    }
                )
                Error=[pscustomobject]@{
                    Code='OrchestrationStageExecutionFailed'
                    Message='The remote server returned an error.'
                }
            }

            $result = ConvertTo-WintainiumPublicApplicationUpdateResult -LifecycleResult $lifecycle

            $result.Stages[0].Sequence | Should -Be 1
            $result.Stages[1].Sequence | Should -Be 4
            $result.Stages[1].Name | Should -Be 'Download'
            $result.Stages[1].Error.Code | Should -Be 'OrchestrationStageStructuredFailure'
            $result.Stages[1].Error.Message | Should -Be 'The remote server returned an error.'
            @($result.Errors).Code | Should -Contain 'OrchestrationStageStructuredFailure'
        }
    }
