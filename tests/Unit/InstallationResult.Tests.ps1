Describe 'New-WintainiumInstallationResult' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '../../core/Wintainium.Core/Wintainium.Core.psd1'
        Import-Module $modulePath -Force
    }

    It 'maps a successful zero-exit process to a completed installation result' {
        $invocation = [pscustomobject]@{ OperationId='op-1'; DownloadOperationId='dl-1'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Completed'; FailureKind=$null; ExitCode=0; StandardOutput='installed'; StandardError=''; DurationMilliseconds=42; ErrorMessage=$null }

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } {
            New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult
        }

        $result.Status | Should -Be 'Completed'
        $result.FailureKind | Should -Be $null
        $result.OperationId | Should -Be 'op-1'
        $result.DownloadOperationId | Should -Be 'dl-1'
        $result.PluginId | Should -Be 'installer.test'
        $result.ExitCode | Should -Be 0
        $result.StandardOutput | Should -Be 'installed'
        $result.DurationMilliseconds | Should -Be 42
        $result.ErrorMessage | Should -Be $null
    }

    It 'preserves a non-zero exit failure from controlled process execution' {
        $invocation = [pscustomobject]@{ OperationId='op-2'; DownloadOperationId='dl-2'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Failed'; FailureKind='NonZeroExit'; ExitCode=17; StandardOutput=''; StandardError='bad'; DurationMilliseconds=8; ErrorMessage='The installer process exited with code 17.' }

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } {
            New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'NonZeroExit'
        $result.ExitCode | Should -Be 17
        $result.StandardError | Should -Be 'bad'
        $result.ErrorMessage | Should -Be 'The installer process exited with code 17.'
    }

    It 'preserves timeout and cancellation failures without inventing exit codes' {
        foreach ($kind in @('Timeout','Cancelled')) {
            $invocation = [pscustomobject]@{ OperationId="op-$kind"; DownloadOperationId="dl-$kind"; PluginId='installer.test' }
            $process = [pscustomobject]@{ Status='Failed'; FailureKind=$kind; ExitCode=$null; StandardOutput='partial'; StandardError=''; DurationMilliseconds=100; ErrorMessage="The installer process was $($kind.ToLowerInvariant())." }

            $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } {
                New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult
            }

            $result.Status | Should -Be 'Failed'
            $result.FailureKind | Should -Be $kind
            $result.ExitCode | Should -Be $null
            $result.StandardOutput | Should -Be 'partial'
        }
    }

    It 'does not treat an arbitrary process result as a successful installation' {
        $invocation = [pscustomobject]@{ OperationId='op-3'; DownloadOperationId='dl-3'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Completed'; FailureKind='Unexpected'; ExitCode=5; StandardOutput=''; StandardError=''; DurationMilliseconds=1; ErrorMessage='unexpected' }

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } {
            New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'Unexpected'
        $result.ExitCode | Should -Be 5
    }

    It 'returns a structured failure when the process result is missing' {
        $invocation = [pscustomobject]@{ OperationId='op-4'; DownloadOperationId='dl-4'; PluginId='installer.test' }

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation } {
            New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $null
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'InvalidProcessResult'
        $result.OperationId | Should -Be 'op-4'
        $result.PluginId | Should -Be 'installer.test'
    }

    It 'returns a structured failure when the invocation is missing' {
        $process = [pscustomobject]@{ Status='Completed'; FailureKind=$null; ExitCode=0; StandardOutput=''; StandardError=''; DurationMilliseconds=1; ErrorMessage=$null }

        $result = InModuleScope Wintainium.Core -Parameters @{ ProcessResult=$process } {
            New-WintainiumInstallationResult -Invocation $null -ProcessResult $ProcessResult
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'InvalidInput'
        $result.OperationId | Should -Be $null
    }

    It 'preserves output, duration, identifiers, and process failure diagnostics' {
        $invocation = [pscustomobject]@{ OperationId='op-5'; DownloadOperationId='dl-5'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Failed'; FailureKind='ProcessStart'; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=3; ErrorMessage='access denied' }

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } {
            New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult
        }

        $result.OperationId | Should -Be 'op-5'
        $result.DownloadOperationId | Should -Be 'dl-5'
        $result.PluginId | Should -Be 'installer.test'
        $result.DurationMilliseconds | Should -Be 3
        $result.ErrorMessage | Should -Be 'access denied'
    }
}
