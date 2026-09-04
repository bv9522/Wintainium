Describe 'New-WintainiumInstallationResult' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '../../core/Wintainium.Core/Wintainium.Core.psd1'
        Import-Module $modulePath -Force
    }

    It 'maps a successful zero-exit process to a completed installation result' {
        $invocation = [pscustomobject]@{ OperationId='op-1'; DownloadOperationId='dl-1'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Completed'; FailureKind=$null; ExitCode=0; StandardOutput='installed'; StandardError=''; DurationMilliseconds=42; ErrorMessage=$null }
        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } { New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult }
        $result.Status | Should -Be 'Completed'; $result.FailureKind | Should -Be $null; $result.OperationId | Should -Be 'op-1'; $result.DownloadOperationId | Should -Be 'dl-1'; $result.PluginId | Should -Be 'installer.test'; $result.ExitCode | Should -Be 0; $result.StandardOutput | Should -Be 'installed'; $result.DurationMilliseconds | Should -Be 42; $result.ErrorMessage | Should -Be $null
    }

    It 'preserves a non-zero exit failure from controlled process execution' {
        $invocation = [pscustomobject]@{ OperationId='op-2'; DownloadOperationId='dl-2'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Failed'; FailureKind='NonZeroExit'; ExitCode=17; StandardOutput=''; StandardError='bad'; DurationMilliseconds=8; ErrorMessage='The installer process exited with code 17.' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } { New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult }
        $result.Status | Should -Be 'Failed'; $result.FailureKind | Should -Be 'NonZeroExit'; $result.ExitCode | Should -Be 17; $result.StandardError | Should -Be 'bad'; $result.ErrorMessage | Should -Be 'The installer process exited with code 17.'
    }

    It 'preserves timeout and cancellation failures without inventing exit codes' {
        foreach ($kind in @('Timeout','Cancelled')) {
            $invocation = [pscustomobject]@{ OperationId="op-$kind"; DownloadOperationId="dl-$kind"; PluginId='installer.test' }
            $process = [pscustomobject]@{ Status='Failed'; FailureKind=$kind; ExitCode=$null; StandardOutput='partial'; StandardError=''; DurationMilliseconds=100; ErrorMessage='interrupted' }
            $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } { New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult }
            $result.Status | Should -Be 'Failed'; $result.FailureKind | Should -Be $kind; $result.ExitCode | Should -Be $null; $result.StandardOutput | Should -Be 'partial'
        }
    }

    It 'does not treat a nonzero process result as a successful installation' {
        $invocation = [pscustomobject]@{ OperationId='op-3'; DownloadOperationId='dl-3'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Completed'; FailureKind='Unexpected'; ExitCode=5; StandardOutput=''; StandardError=''; DurationMilliseconds=1; ErrorMessage='unexpected' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } { New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult }
        $result.Status | Should -Be 'Failed'; $result.FailureKind | Should -Be 'Unexpected'; $result.ExitCode | Should -Be 5
    }

    It 'returns a structured failure when the process result is missing' {
        $invocation = [pscustomobject]@{ OperationId='op-4'; DownloadOperationId='dl-4'; PluginId='installer.test' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation } { New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $null }
        $result.Status | Should -Be 'Failed'; $result.FailureKind | Should -Be 'InvalidProcessResult'; $result.OperationId | Should -Be 'op-4'; $result.PluginId | Should -Be 'installer.test'
    }

    It 'returns a structured failure when the invocation is missing' {
        $process = [pscustomobject]@{ Status='Completed'; FailureKind=$null; ExitCode=0; StandardOutput=''; StandardError=''; DurationMilliseconds=1; ErrorMessage=$null }
        $result = InModuleScope Wintainium.Core -Parameters @{ ProcessResult=$process } { New-WintainiumInstallationResult -Invocation $null -ProcessResult $ProcessResult }
        $result.Status | Should -Be 'Failed'; $result.FailureKind | Should -Be 'InvalidInput'; $result.OperationId | Should -Be $null
    }

    It 'preserves identifiers, duration, and process failure diagnostics' {
        $invocation = [pscustomobject]@{ OperationId='op-5'; DownloadOperationId='dl-5'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Failed'; FailureKind='ProcessStart'; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=3; ErrorMessage='access denied' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } { New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult }
        $result.OperationId | Should -Be 'op-5'; $result.DownloadOperationId | Should -Be 'dl-5'; $result.PluginId | Should -Be 'installer.test'; $result.DurationMilliseconds | Should -Be 3; $result.ErrorMessage | Should -Be 'access denied'
    }

    It 'does not treat an unknown process status as success' {
        $invocation = [pscustomobject]@{ OperationId='op-6'; DownloadOperationId='dl-6'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Unknown'; FailureKind=$null; ExitCode=0; StandardOutput=''; StandardError=''; DurationMilliseconds=4; ErrorMessage='unrecognized status' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } { New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult }
        $result.Status | Should -Be 'Failed'; $result.FailureKind | Should -Be 'ProcessFailed'; $result.ExitCode | Should -Be 0
    }

    It 'does not treat a completed process with a missing exit code as success' {
        $invocation = [pscustomobject]@{ OperationId='op-7'; DownloadOperationId='dl-7'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Completed'; FailureKind=$null; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=5; ErrorMessage=$null }
        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } { New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult }
        $result.Status | Should -Be 'Failed'; $result.FailureKind | Should -Be 'ProcessFailed'; $result.ExitCode | Should -Be $null
    }

    It 'uses ProcessFailed when a failed process result has no failure classification' {
        $invocation = [pscustomobject]@{ OperationId='op-8'; DownloadOperationId='dl-8'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Failed'; FailureKind=''; ExitCode=$null; StandardOutput='partial'; StandardError='diagnostic'; DurationMilliseconds=6; ErrorMessage='process failed' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } { New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult }
        $result.Status | Should -Be 'Failed'; $result.FailureKind | Should -Be 'ProcessFailed'; $result.StandardOutput | Should -Be 'partial'; $result.StandardError | Should -Be 'diagnostic'
    }

    It 'preserves successful stderr as process diagnostics while clearing the result error' {
        $invocation = [pscustomobject]@{ OperationId='op-9'; DownloadOperationId='dl-9'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Completed'; FailureKind=''; ExitCode=0; StandardOutput='installed'; StandardError='warning: restart recommended'; DurationMilliseconds=7; ErrorMessage='stale error' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } { New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult }
        $result.Status | Should -Be 'Completed'; $result.FailureKind | Should -Be $null; $result.StandardError | Should -Be 'warning: restart recommended'; $result.ErrorMessage | Should -Be $null
    }

    It 'normalizes missing optional process diagnostics deterministically' {
        $invocation = [pscustomobject]@{ OperationId='op-10'; DownloadOperationId='dl-10'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Failed'; FailureKind='ProcessStart'; ExitCode=$null; DurationMilliseconds=0 }
        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$ProcessResult }
        $result.StandardOutput | Should -Be ''; $result.StandardError | Should -Be ''; $result.DurationMilliseconds | Should -Be 0; $result.ErrorMessage | Should -Be $null
    }

    It 'does not treat a string zero exit code as successful installation' {
        $invocation = [pscustomobject]@{ OperationId='op-11'; DownloadOperationId='dl-11'; PluginId='installer.test' }
        $process = [pscustomobject]@{ Status='Completed'; FailureKind=$null; ExitCode='0'; StandardOutput='installed'; StandardError=''; DurationMilliseconds=9; ErrorMessage=$null }
        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; ProcessResult=$process } { New-WintainiumInstallationResult -Invocation $Invocation -ProcessResult $ProcessResult }
        $result.Status | Should -Be 'Failed'; $result.FailureKind | Should -Be 'ProcessFailed'; $result.ExitCode | Should -Be '0'
    }
}
