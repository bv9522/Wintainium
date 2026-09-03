BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force
    $script:pwshPath = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
    $script:tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('Wintainium-InstallerProcess-' + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
}
AfterAll { Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
Describe 'Wintainium installer process lifecycle' {
    It 'runs a process with structured arguments and captures standard output' {
        $result = InModuleScope Wintainium.Core -Parameters @{ FilePath = $script:pwshPath } {
            Invoke-WintainiumInstallerProcess -FilePath $FilePath -ArgumentList @('-NoProfile','-NonInteractive','-Command','Write-Output ''hello from wintainium''') -TimeoutMilliseconds 10000
        }
        $result.Status | Should -Be 'Completed'
        $result.FailureKind | Should -Be $null
        $result.ExitCode | Should -Be 0
        $result.StandardOutput | Should -Match 'hello from wintainium'
        $result.StandardError | Should -Be ''
    }
    It 'preserves argument boundaries instead of constructing shell command text' {
        $argumentWithSpaces = 'value with spaces'
        $result = InModuleScope Wintainium.Core -Parameters @{ FilePath = $script:pwshPath; Value = $argumentWithSpaces } {
            Invoke-WintainiumInstallerProcess -FilePath $FilePath -ArgumentList @('-NoProfile','-NonInteractive','-Command','param($value); Write-Output $value','--',$Value) -TimeoutMilliseconds 10000
        }
        $result.Status | Should -Be 'Completed'
        $result.StandardOutput | Should -Match [regex]::Escape($argumentWithSpaces)
    }
    It 'captures standard error and reports a non-zero exit code' {
        $result = InModuleScope Wintainium.Core -Parameters @{ FilePath = $script:pwshPath } {
            Invoke-WintainiumInstallerProcess -FilePath $FilePath -ArgumentList @('-NoProfile','-NonInteractive','-Command','[Console]::Error.WriteLine(''installer failure''); exit 7') -TimeoutMilliseconds 10000
        }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'NonZeroExit'
        $result.ExitCode | Should -Be 7
        $result.StandardError | Should -Match 'installer failure'
    }
    It 'rejects a non-absolute process path' {
        $result = InModuleScope Wintainium.Core { Invoke-WintainiumInstallerProcess -FilePath 'pwsh.exe' }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'ProcessPathNotAbsolute'
    }
    It 'rejects a missing process path' {
        $missingPath = Join-Path $script:tempRoot 'missing.exe'
        $result = InModuleScope Wintainium.Core -Parameters @{ FilePath = $missingPath } { Invoke-WintainiumInstallerProcess -FilePath $FilePath }
        $result.FailureKind | Should -Be 'ProcessPathMissing'
    }
    It 'rejects a missing working directory' {
        $missingDirectory = Join-Path $script:tempRoot 'missing-directory'
        $result = InModuleScope Wintainium.Core -Parameters @{ FilePath = $script:pwshPath; WorkingDirectory = $missingDirectory } { Invoke-WintainiumInstallerProcess -FilePath $FilePath -WorkingDirectory $WorkingDirectory }
        $result.FailureKind | Should -Be 'WorkingDirectoryMissing'
    }
    It 'passes controlled environment variables to the child process' {
        $result = InModuleScope Wintainium.Core -Parameters @{ FilePath = $script:pwshPath } {
            Invoke-WintainiumInstallerProcess -FilePath $FilePath -EnvironmentVariables ([ordered]@{ WINTAINIUM_TEST_VALUE = 'controlled-value' }) -ArgumentList @('-NoProfile','-NonInteractive','-Command','Write-Output $env:WINTAINIUM_TEST_VALUE') -TimeoutMilliseconds 10000
        }
        $result.Status | Should -Be 'Completed'
        $result.StandardOutput | Should -Match 'controlled-value'
    }
    It 'returns Timeout when the process exceeds the lifecycle limit' {
        $result = InModuleScope Wintainium.Core -Parameters @{ FilePath = $script:pwshPath } {
            Invoke-WintainiumInstallerProcess -FilePath $FilePath -ArgumentList @('-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 30') -TimeoutMilliseconds 100
        }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'Timeout'
        $result.ExitCode | Should -Be $null
        $result.ErrorMessage | Should -Match '100 millisecond timeout'
    }
    It 'returns Cancelled when the cancellation token is signaled' {
        $cts = [System.Threading.CancellationTokenSource]::new()
        try {
            $cts.CancelAfter(100)
            $result = InModuleScope Wintainium.Core -Parameters @{ FilePath = $script:pwshPath; Token = $cts.Token } {
                Invoke-WintainiumInstallerProcess -FilePath $FilePath -ArgumentList @('-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 30') -CancellationToken $Token -TimeoutMilliseconds 10000
            }
            $result.Status | Should -Be 'Failed'
            $result.FailureKind | Should -Be 'Cancelled'
            $result.ExitCode | Should -Be $null
        }
        finally { $cts.Dispose() }
    }
    It 'treats a successful zero exit code as completed' {
        $result = InModuleScope Wintainium.Core -Parameters @{ FilePath = $script:pwshPath } {
            Invoke-WintainiumInstallerProcess -FilePath $FilePath -ArgumentList @('-NoProfile','-NonInteractive','-Command','exit 0') -TimeoutMilliseconds 10000
        }
        $result.Status | Should -Be 'Completed'
        $result.ExitCode | Should -Be 0
    }
}
