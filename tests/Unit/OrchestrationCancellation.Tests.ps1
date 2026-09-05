BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
    Import-Module $modulePath -Force

    $operationId = [guid]::NewGuid().ToString()

    function New-TestOperationState {
        [pscustomobject][ordered]@{
            OperationId = $operationId
            Status = 'Running'
            CurrentStageSequence = 1
            CurrentStageName = 'ManifestValidation'
            CompletedStages = @()
            StageResults = @()
            FailedStage = $null
            Error = $null
        }
    }
}

Describe 'New-WintainiumOrchestrationCancellationContext' {
    It 'creates a context with no cancellation requested by default' {
        $state = New-TestOperationState

        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state } {
            param($OperationState)
            New-WintainiumOrchestrationCancellationContext -OperationState $OperationState
        }

        $result.IsValid | Should -BeTrue
        $result.Context.OperationId | Should -Be $operationId
        $result.Context.IsCancellationRequested | Should -BeFalse
        $result.Context.CancellationToken.IsCancellationRequested | Should -BeFalse
    }

    It 'preserves a caller-supplied cancellation token' {
        $state = New-TestOperationState
        $source = [System.Threading.CancellationTokenSource]::new()

        try {
            $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; CancellationToken = $source.Token } {
                param($OperationState, $CancellationToken)
                New-WintainiumOrchestrationCancellationContext -OperationState $OperationState -CancellationToken $CancellationToken
            }

            $result.IsValid | Should -BeTrue
            $result.Context.CancellationToken.CanBeCanceled | Should -BeTrue
            $result.Context.IsCancellationRequested | Should -BeFalse

            $source.Cancel()
            $result.Context.CancellationToken.IsCancellationRequested | Should -BeTrue
        }
        finally {
            $source.Dispose()
        }
    }

    It 'captures an already-requested cancellation token as requested' {
        $state = New-TestOperationState
        $source = [System.Threading.CancellationTokenSource]::new()

        try {
            $source.Cancel()

            $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; CancellationToken = $source.Token } {
                param($OperationState, $CancellationToken)
                New-WintainiumOrchestrationCancellationContext -OperationState $OperationState -CancellationToken $CancellationToken
            }

            $result.IsValid | Should -BeTrue
            $result.Context.IsCancellationRequested | Should -BeTrue
            $result.Context.CancellationToken.IsCancellationRequested | Should -BeTrue
        }
        finally {
            $source.Dispose()
        }
    }

    It 'rejects a null operation state structurally' {
        $result = InModuleScope Wintainium.Core {
            New-WintainiumOrchestrationCancellationContext -OperationState $null
        }

        $result.IsValid | Should -BeFalse
        $result.Context | Should -BeNullOrEmpty
        $result.Errors.Code | Should -Contain 'OrchestrationCancellationStateMissing'
    }

    It 'rejects an operation state without an operation identifier' {
        $state = New-TestOperationState
        $state.OperationId = $null

        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state } {
            param($OperationState)
            New-WintainiumOrchestrationCancellationContext -OperationState $OperationState
        }

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationCancellationOperationIdMissing'
    }

    It 'rejects an operation state with an invalid operation identifier' {
        $state = New-TestOperationState
        $state.OperationId = 'not-a-guid'

        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state } {
            param($OperationState)
            New-WintainiumOrchestrationCancellationContext -OperationState $OperationState
        }

        $result.IsValid | Should -BeFalse
        $result.Errors.Code | Should -Contain 'OrchestrationCancellationOperationIdInvalid'
    }

    It 'does not mutate operation state when creating the context' {
        $state = New-TestOperationState
        $before = $state | ConvertTo-Json -Depth 10

        $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state } {
            param($OperationState)
            New-WintainiumOrchestrationCancellationContext -OperationState $OperationState
        }

        $result.IsValid | Should -BeTrue
        ($state | ConvertTo-Json -Depth 10) | Should -Be $before
    }

    It 'does not cancel the supplied token itself' {
        $state = New-TestOperationState
        $source = [System.Threading.CancellationTokenSource]::new()

        try {
            $result = InModuleScope Wintainium.Core -Parameters @{ OperationState = $state; CancellationToken = $source.Token } {
                param($OperationState, $CancellationToken)
                New-WintainiumOrchestrationCancellationContext -OperationState $OperationState -CancellationToken $CancellationToken
            }

            $result.IsValid | Should -BeTrue
            $source.IsCancellationRequested | Should -BeFalse
        }
        finally {
            $source.Dispose()
        }
    }
}