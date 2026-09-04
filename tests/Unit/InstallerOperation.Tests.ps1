Describe 'Invoke-WintainiumInstallerOperation' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '../../core/Wintainium.Core/Wintainium.Core.psd1'
        Import-Module $modulePath -Force

        function New-TestInvocation {
            param([string]$PluginModulePath)
            [pscustomobject]@{
                OperationId = 'op-installer-1'
                DownloadOperationId = 'dl-installer-1'
                PluginId = 'Wintainium.installer.valid-fixture'
                PluginModulePath = $PluginModulePath
                ArtifactPath = (Join-Path $TestDrive 'artifact.exe')
                ArtifactFormat = 'exe'
                Settings = [pscustomobject]@{}
            }
        }
    }

    It 'composes plugin planning, controlled process execution, and structured result creation' {
        $modulePath = Join-Path $PSScriptRoot '../Fixtures/Plugins/ValidInstaller/Wintainium.installer.valid-fixture.psm1'
        $invocation = New-TestInvocation -PluginModulePath $modulePath
        Set-Content -LiteralPath $invocation.ArtifactPath -Value 'fixture-artifact' -NoNewline

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation } {
            Invoke-WintainiumInstallerOperation -Invocation $Invocation -TimeoutMilliseconds 10000
        }

        $result.Status | Should -Be 'Completed'
        $result.FailureKind | Should -Be $null
        $result.OperationId | Should -Be 'op-installer-1'
        $result.DownloadOperationId | Should -Be 'dl-installer-1'
        $result.PluginId | Should -Be 'Wintainium.installer.valid-fixture'
        $result.ExitCode | Should -Be 0
        $result.StandardOutput.Trim() | Should -Be 'fixture-installer-completed'
        $result.ErrorMessage | Should -Be $null
    }

    It 'rejects an installer plugin that does not export the fixed operation' {
        $pluginRoot = Join-Path $TestDrive 'MissingOperation'
        New-Item -ItemType Directory -Path $pluginRoot | Out-Null
        $modulePath = Join-Path $pluginRoot 'missing-operation.psm1'
        Set-Content -LiteralPath $modulePath -Value 'Export-ModuleMember -Function None' -NoNewline
        $invocation = New-TestInvocation -PluginModulePath $modulePath

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation } {
            Invoke-WintainiumInstallerOperation -Invocation $Invocation -TimeoutMilliseconds 1000
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'InstallerOperationNotFound'
        $result.ExitCode | Should -Be $null
    }

    It 'rejects a plugin result with a relative executable path' {
        $pluginRoot = Join-Path $TestDrive 'RelativeExecutable'
        New-Item -ItemType Directory -Path $pluginRoot | Out-Null
        $modulePath = Join-Path $pluginRoot 'relative.psm1'
        Set-Content -LiteralPath $modulePath -Value @'
function Invoke-WintainiumInstaller {
    param([psobject]$Invocation)
    [pscustomobject]@{ ExecutablePath = 'pwsh.exe'; Arguments = @() }
}
Export-ModuleMember -Function Invoke-WintainiumInstaller
'@ -NoNewline
        $invocation = New-TestInvocation -PluginModulePath $modulePath

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation } {
            Invoke-WintainiumInstallerOperation -Invocation $Invocation -TimeoutMilliseconds 1000
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'InstallerProcessSpecificationInvalid'
        $result.ExitCode | Should -Be $null
    }

    It 'rejects non-string process arguments before reaching the process boundary' {
        $pluginRoot = Join-Path $TestDrive 'NonStringArguments'
        New-Item -ItemType Directory -Path $pluginRoot | Out-Null
        $modulePath = Join-Path $pluginRoot 'invalid.psm1'
        $pwshPath = Join-Path $PSHOME 'pwsh.exe'
        Set-Content -LiteralPath $modulePath -Value @"
function Invoke-WintainiumInstaller {
    param([psobject]`$Invocation)
    [pscustomobject]@{ ExecutablePath = '$pwshPath'; Arguments = @('-NoProfile', 7) }
}
Export-ModuleMember -Function Invoke-WintainiumInstaller
"@ -NoNewline
        $invocation = New-TestInvocation -PluginModulePath $modulePath

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation } {
            Invoke-WintainiumInstallerOperation -Invocation $Invocation -TimeoutMilliseconds 1000
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'InstallerProcessSpecificationInvalid'
    }

    It 'preserves structured argument boundaries, working directory, and environment overrides' {
        $pluginRoot = Join-Path $TestDrive 'ProcessInputs'
        $workingDirectory = Join-Path $pluginRoot 'Work'
        New-Item -ItemType Directory -Path $workingDirectory -Force | Out-Null
        $modulePath = Join-Path $pluginRoot 'inputs.psm1'
        $pwshPath = Join-Path $PSHOME 'pwsh.exe'
        $script = 'Write-Output (($args -join "<SEP>") + "<SEP>" + $env:WINTAINIUM_TEST_VALUE + "<SEP>" + (Get-Location).Path)'
        Set-Content -LiteralPath $modulePath -Value @"
function Invoke-WintainiumInstaller {
    param([psobject]`$Invocation)
    [pscustomobject]@{
        ExecutablePath = '$pwshPath'
        Arguments = @('-NoProfile', '-CommandWithArgs', '$script', 'alpha beta', 'quote"value', 'semi;pipe')
        WorkingDirectory = '$workingDirectory'
        EnvironmentVariables = @{ WINTAINIUM_TEST_VALUE = 'fixture-value' }
    }
}
Export-ModuleMember -Function Invoke-WintainiumInstaller
"@ -NoNewline
        $invocation = New-TestInvocation -PluginModulePath $modulePath

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation } {
            Invoke-WintainiumInstallerOperation -Invocation $Invocation -TimeoutMilliseconds 10000
        }

        $expected = "alpha beta<SEP>quote`"value<SEP>semi;pipe<SEP>fixture-value<SEP>$workingDirectory"
        $result.Status | Should -Be 'Completed'
        $result.StandardOutput.Trim() | Should -Be $expected
    }

    It 'rejects an invalid working directory before reaching the process boundary' {
        $pluginRoot = Join-Path $TestDrive 'InvalidWorkingDirectory'
        New-Item -ItemType Directory -Path $pluginRoot | Out-Null
        $modulePath = Join-Path $pluginRoot 'invalid-working-directory.psm1'
        $pwshPath = Join-Path $PSHOME 'pwsh.exe'
        $missingDirectory = Join-Path $pluginRoot 'missing'
        Set-Content -LiteralPath $modulePath -Value @"
function Invoke-WintainiumInstaller {
    param([psobject]`$Invocation)
    [pscustomobject]@{ ExecutablePath = '$pwshPath'; Arguments = @(); WorkingDirectory = '$missingDirectory' }
}
Export-ModuleMember -Function Invoke-WintainiumInstaller
"@ -NoNewline
        $invocation = New-TestInvocation -PluginModulePath $modulePath

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation } {
            Invoke-WintainiumInstallerOperation -Invocation $Invocation -TimeoutMilliseconds 1000
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'InstallerProcessSpecificationInvalid'
    }

    It 'rejects an invalid environment variable name before reaching the process boundary' {
        $pluginRoot = Join-Path $TestDrive 'InvalidEnvironment'
        New-Item -ItemType Directory -Path $pluginRoot | Out-Null
        $modulePath = Join-Path $pluginRoot 'invalid-environment.psm1'
        $pwshPath = Join-Path $PSHOME 'pwsh.exe'
        Set-Content -LiteralPath $modulePath -Value @"
function Invoke-WintainiumInstaller {
    param([psobject]`$Invocation)
    [pscustomobject]@{ ExecutablePath = '$pwshPath'; Arguments = @(); EnvironmentVariables = @{ 'BAD-NAME' = 'value' } }
}
Export-ModuleMember -Function Invoke-WintainiumInstaller
"@ -NoNewline
        $invocation = New-TestInvocation -PluginModulePath $modulePath

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation } {
            Invoke-WintainiumInstallerOperation -Invocation $Invocation -TimeoutMilliseconds 1000
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'InstallerProcessSpecificationInvalid'
    }

    It 'rejects a plugin that returns multiple process specifications' {
        $pluginRoot = Join-Path $TestDrive 'MultipleResults'
        New-Item -ItemType Directory -Path $pluginRoot | Out-Null
        $modulePath = Join-Path $pluginRoot 'multiple-results.psm1'
        $pwshPath = Join-Path $PSHOME 'pwsh.exe'
        Set-Content -LiteralPath $modulePath -Value @"
function Invoke-WintainiumInstaller {
    param([psobject]`$Invocation)
    [pscustomobject]@{ ExecutablePath = '$pwshPath'; Arguments = @() }
    [pscustomobject]@{ ExecutablePath = '$pwshPath'; Arguments = @() }
}
Export-ModuleMember -Function Invoke-WintainiumInstaller
"@ -NoNewline
        $invocation = New-TestInvocation -PluginModulePath $modulePath

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation } {
            Invoke-WintainiumInstallerOperation -Invocation $Invocation -TimeoutMilliseconds 1000
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'InstallerResultInvalid'
    }

    It 'converts installer plugin exceptions into a structured failure' {
        $pluginRoot = Join-Path $TestDrive 'PluginException'
        New-Item -ItemType Directory -Path $pluginRoot | Out-Null
        $modulePath = Join-Path $pluginRoot 'exception.psm1'
        Set-Content -LiteralPath $modulePath -Value @'
function Invoke-WintainiumInstaller {
    param([psobject]$Invocation)
    throw 'fixture installer failure'
}
Export-ModuleMember -Function Invoke-WintainiumInstaller
'@ -NoNewline
        $invocation = New-TestInvocation -PluginModulePath $modulePath

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation } {
            Invoke-WintainiumInstallerOperation -Invocation $Invocation -TimeoutMilliseconds 1000
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'InstallerInternalError'
        $result.ExitCode | Should -Be $null
    }

    It 'preserves controlled process timeout and cancellation semantics through the result boundary' {
        $pluginRoot = Join-Path $TestDrive 'Lifecycle'
        New-Item -ItemType Directory -Path $pluginRoot | Out-Null
        $modulePath = Join-Path $pluginRoot 'lifecycle.psm1'
        $pwshPath = Join-Path $PSHOME 'pwsh.exe'
        Set-Content -LiteralPath $modulePath -Value @"
function Invoke-WintainiumInstaller {
    param([psobject]`$Invocation)
    [pscustomobject]@{ ExecutablePath = '$pwshPath'; Arguments = @('-NoProfile', '-Command', 'Start-Sleep -Seconds 5') }
}
Export-ModuleMember -Function Invoke-WintainiumInstaller
"@ -NoNewline
        $invocation = New-TestInvocation -PluginModulePath $modulePath
        $cts = [System.Threading.CancellationTokenSource]::new()
        $cts.Cancel()

        $result = InModuleScope Wintainium.Core -Parameters @{ Invocation=$invocation; CancellationToken=$cts.Token } {
            Invoke-WintainiumInstallerOperation -Invocation $Invocation -TimeoutMilliseconds 10000 -CancellationToken $CancellationToken
        }

        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'Cancelled'
        $result.ExitCode | Should -Be $null
    }
}
