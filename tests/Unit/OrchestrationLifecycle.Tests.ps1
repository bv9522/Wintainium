Describe 'Invoke-WintainiumOrchestrationLifecycle' {
    BeforeAll {
        function New-TestRequest {
            param([Parameter(Mandatory)][string]$OperationId)
            [pscustomobject][ordered]@{
                OperationId = $OperationId
                ManifestPath = 'C:\Wintainium\example.wintainium.json'
                MachineArchitecture = 'x64'
                DownloadRoot = 'C:\Wintainium\Downloads'
            }
        }

        function New-TestStagePlan {
            param([Parameter(Mandatory)][string]$OperationId)
            [pscustomobject][ordered]@{
                OperationId = $OperationId
                Stages = @(
                    [pscustomobject]@{ Sequence = 1; Name = 'ManifestValidation' }
                    [pscustomobject]@{ Sequence = 2; Name = 'ReleaseDiscovery' }
                )
            }
        }

        function New-TestContext {
            param([Parameter(Mandatory)][string]$OperationId, [System.Threading.CancellationToken]$Token = [System.Threading.CancellationToken]::None)
            [pscustomobject][ordered]@{
                OperationId = $OperationId
                CancellationToken = $Token
                IsCancellationRequested = $Token.IsCancellationRequested
            }
        }

        InModuleScope Wintainium.Core {
            function New-TestBinding {
                param([object]$InputValue, [scriptblock]$Executor)
                [pscustomobject][ordered]@{ StageInput = $InputValue; StageExecutor = $Executor }
            }
        }
    }

    It 'initializes state and delegates the complete lifecycle to the workflow' {
        $operationId = [guid]::NewGuid().Guid
        $request = New-TestRequest $operationId
        $plan = New-TestStagePlan $operationId
        $context = New-TestContext $operationId
        $seen = [System.Collections.Generic.List[int]]::new()

        $result = InModuleScope Wintainium.Core -Parameters @{ Request = $request; StagePlan = $plan; CancellationContext = $context; Seen = $seen } {
            param($Request, $StagePlan, $CancellationContext, $Seen)
            Invoke-WintainiumOrchestrationLifecycle -Request $Request -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory {
                param($Stage, $State, $Context)
                $Seen.Add([int]$Stage.Sequence)
                New-TestBinding $Stage.Name { param($StageInput, $CancellationToken) $StageInput }
            }
        }

        $result.IsSuccessful | Should -BeTrue
        $result.WasCancelled | Should -BeFalse
        $result.OperationId | Should -Be $operationId
        $result.State.Status | Should -Be 'Completed'
        $result.State.CompletedStages.Count | Should -Be 2
        @($seen) | Should -Be @(1, 2)
    }

    It 'preserves the supplied request and parent operation identifier' {
        $operationId = [guid]::NewGuid().Guid
        $request = New-TestRequest $operationId
        $plan = New-TestStagePlan $operationId
        $context = New-TestContext $operationId

        $result = InModuleScope Wintainium.Core -Parameters @{ Request = $request; StagePlan = $plan; CancellationContext = $context } {
            param($Request, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationLifecycle -Request $Request -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory {
                param($Stage, $State, $Context) New-TestBinding $Stage.Name { param($StageInput, $CancellationToken) $StageInput }
            }
        }

        $result.Request | Should -Be $request
        $result.Request.OperationId | Should -Be $operationId
        $result.State.OperationId | Should -Be $operationId
        $result.StageResults[0].OperationId | Should -Be $operationId
    }

    It 'rejects request and stage-plan operation-id mismatch before execution' {
        $requestId = [guid]::NewGuid().Guid
        $planId = [guid]::NewGuid().Guid
        $request = New-TestRequest $requestId
        $plan = New-TestStagePlan $planId
        $context = New-TestContext $requestId
        $called = $false

        $result = InModuleScope Wintainium.Core -Parameters @{ Request = $request; StagePlan = $plan; CancellationContext = $context } {
            param($Request, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationLifecycle -Request $Request -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory { $script:called = $true; throw 'must not execute' }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Error.Code | Should -Be 'OrchestrationLifecycleOperationIdMismatch'
        $result.State | Should -BeNullOrEmpty
        $result.StageResults.Count | Should -Be 0
    }

    It 'rejects cancellation-context operation-id mismatch before execution' {
        $operationId = [guid]::NewGuid().Guid
        $request = New-TestRequest $operationId
        $plan = New-TestStagePlan $operationId
        $context = New-TestContext ([guid]::NewGuid().Guid)

        $result = InModuleScope Wintainium.Core -Parameters @{ Request = $request; StagePlan = $plan; CancellationContext = $context } {
            param($Request, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationLifecycle -Request $Request -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory { throw 'must not execute' }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Error.Code | Should -Be 'OrchestrationLifecycleOperationIdMismatch'
        $result.State | Should -BeNullOrEmpty
    }

    It 'returns structured state-initialization failure for an invalid stage plan' {
        $operationId = [guid]::NewGuid().Guid
        $request = New-TestRequest $operationId
        $plan = [pscustomobject]@{ OperationId = $operationId; Stages = @() }
        $context = New-TestContext $operationId

        $result = InModuleScope Wintainium.Core -Parameters @{ Request = $request; StagePlan = $plan; CancellationContext = $context } {
            param($Request, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationLifecycle -Request $Request -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory { throw 'must not execute' }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Error.Code | Should -Be 'OrchestrationLifecycleStateInitializationFailed'
        $result.State | Should -BeNullOrEmpty
        $result.StageResults.Count | Should -Be 0
    }

    It 'fails fast through the workflow and returns the committed failed state' {
        $operationId = [guid]::NewGuid().Guid
        $request = New-TestRequest $operationId
        $plan = New-TestStagePlan $operationId
        $context = New-TestContext $operationId

        $result = InModuleScope Wintainium.Core -Parameters @{ Request = $request; StagePlan = $plan; CancellationContext = $context } {
            param($Request, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationLifecycle -Request $Request -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory {
                param($Stage, $State, $Context)
                if ($Stage.Sequence -eq 1) { New-TestBinding $Stage.Name { throw 'fixture failure' } }
                else { New-TestBinding $Stage.Name { param($StageInput, $CancellationToken) $StageInput } }
            }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.WasCancelled | Should -BeFalse
        $result.State.Status | Should -Be 'Failed'
        $result.State.FailedStage.Sequence | Should -Be 1
        $result.StageResults.Count | Should -Be 1
    }

    It 'propagates workflow cancellation without creating a Cancelled state' {
        $operationId = [guid]::NewGuid().Guid
        $request = New-TestRequest $operationId
        $plan = New-TestStagePlan $operationId
        $cts = [System.Threading.CancellationTokenSource]::new()
        try {
            $cts.Cancel()
            $context = New-TestContext $operationId $cts.Token
            $result = InModuleScope Wintainium.Core -Parameters @{ Request = $request; StagePlan = $plan; CancellationContext = $context } {
                param($Request, $StagePlan, $CancellationContext)
                Invoke-WintainiumOrchestrationLifecycle -Request $Request -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory { throw 'must not execute' }
            }

            $result.IsSuccessful | Should -BeFalse
            $result.WasCancelled | Should -BeTrue
            $result.State.Status | Should -Be 'Pending'
            $result.State.PSObject.Properties['Cancelled'] | Should -BeNullOrEmpty
        } finally { $cts.Dispose() }
    }

    It 'does not mutate the request, plan, or cancellation context' {
        $operationId = [guid]::NewGuid().Guid
        $request = New-TestRequest $operationId
        $plan = New-TestStagePlan $operationId
        $context = New-TestContext $operationId
        $requestSnapshot = $request | ConvertTo-Json -Depth 10 -Compress
        $planSnapshot = $plan | ConvertTo-Json -Depth 10 -Compress
        $contextSnapshot = $context | ConvertTo-Json -Depth 10 -Compress

        [void](InModuleScope Wintainium.Core -Parameters @{ Request = $request; StagePlan = $plan; CancellationContext = $context } {
            param($Request, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationLifecycle -Request $Request -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory {
                param($Stage, $State, $Context) New-TestBinding $Stage.Name { param($StageInput, $CancellationToken) $StageInput }
            }
        })

        ($request | ConvertTo-Json -Depth 10 -Compress) | Should -Be $requestSnapshot
        ($plan | ConvertTo-Json -Depth 10 -Compress) | Should -Be $planSnapshot
        ($context | ConvertTo-Json -Depth 10 -Compress) | Should -Be $contextSnapshot
    }

    It 'returns structured failure when the stage factory fails before binding' {
        $operationId = [guid]::NewGuid().Guid
        $request = New-TestRequest $operationId
        $plan = New-TestStagePlan $operationId
        $context = New-TestContext $operationId

        $result = InModuleScope Wintainium.Core -Parameters @{ Request = $request; StagePlan = $plan; CancellationContext = $context } {
            param($Request, $StagePlan, $CancellationContext)
            Invoke-WintainiumOrchestrationLifecycle -Request $Request -StagePlan $StagePlan -CancellationContext $CancellationContext -StageFactory { throw 'factory failure' }
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Error.Code | Should -Be 'OrchestrationWorkflowStageFactoryFailed'
        $result.State.Status | Should -Be 'Pending'
        $result.StageResults.Count | Should -Be 0
    }
}
