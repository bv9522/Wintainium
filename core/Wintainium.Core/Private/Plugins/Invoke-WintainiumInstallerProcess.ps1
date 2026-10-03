function Invoke-WintainiumInstallerProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter()]
        [string[]]$ArgumentList = @(),
        [Parameter()]
        [string]$WorkingDirectory,
        [Parameter()]
        [System.Collections.IDictionary]$EnvironmentVariables,
        [Parameter()]
        [ValidateRange(1, 2147483647)]
        [int]$TimeoutMilliseconds = 300000,
        [Parameter()]
        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
    )

    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='ProcessPathInvalid'; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=0; ErrorMessage='The process path is required.' }
    }
    if (-not [System.IO.Path]::IsPathFullyQualified($FilePath)) {
        return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='ProcessPathNotAbsolute'; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=0; ErrorMessage='The process path must be absolute.' }
    }
    $resolvedFilePath = [System.IO.Path]::GetFullPath($FilePath)
    if (-not (Test-Path -LiteralPath $resolvedFilePath -PathType Leaf)) {
        return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='ProcessPathMissing'; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=0; ErrorMessage='The process executable was not found.' }
    }

    $resolvedWorkingDirectory = $null
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        if (-not [System.IO.Path]::IsPathFullyQualified($WorkingDirectory)) {
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='WorkingDirectoryInvalid'; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=0; ErrorMessage='The working directory must be an absolute path when supplied.' }
        }
        $resolvedWorkingDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory)
        if (-not (Test-Path -LiteralPath $resolvedWorkingDirectory -PathType Container)) {
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='WorkingDirectoryMissing'; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=0; ErrorMessage='The working directory was not found.' }
        }
    }

    if ($null -ne $EnvironmentVariables) {
        foreach ($key in $EnvironmentVariables.Keys) {
            if ([string]::IsNullOrWhiteSpace([string]$key)) {
                return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='EnvironmentInvalid'; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=0; ErrorMessage='Environment variable names must be non-empty.' }
            }
        }
    }

    $startTime = [System.Diagnostics.Stopwatch]::GetTimestamp()

    if ($CancellationToken.IsCancellationRequested) {
        return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='Cancelled'; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=0; ErrorMessage='The installer process was cancelled before it started.' }
    }

    $process = [System.Diagnostics.Process]::new()
    try {
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $resolvedFilePath
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true
        if ($null -ne $resolvedWorkingDirectory) { $startInfo.WorkingDirectory = $resolvedWorkingDirectory }
        foreach ($argument in @($ArgumentList)) { [void]$startInfo.ArgumentList.Add([string]$argument) }
        if ($null -ne $EnvironmentVariables) {
            foreach ($key in $EnvironmentVariables.Keys) {
                $startInfo.Environment[[string]$key] = [string]$EnvironmentVariables[$key]
            }
        }
        $process.StartInfo = $startInfo

        $started = $false
        try {
            [void]$process.Start()
            $started = $true
        }
        catch {
            $win32Exception = $_.Exception
            while ($null -ne $win32Exception -and $win32Exception -isnot [System.ComponentModel.Win32Exception] -and $null -ne $win32Exception.InnerException) {
                $win32Exception = $win32Exception.InnerException
            }

            $nativeErrorCode = if ($win32Exception -is [System.ComponentModel.Win32Exception]) { $win32Exception.NativeErrorCode } else { $null }

            if ($nativeErrorCode -eq 740) {
                if ($null -ne $EnvironmentVariables -and $EnvironmentVariables.Count -gt 0) {
                    return [pscustomobject][ordered]@{
                        Status='Failed'
                        FailureKind='ElevationEnvironmentUnsupported'
                        ExitCode=$null
                        StandardOutput=''
                        StandardError=''
                        DurationMilliseconds=[int][math]::Round(([System.Diagnostics.Stopwatch]::GetTimestamp() - $startTime) * 1000 / [System.Diagnostics.Stopwatch]::Frequency)
                        ErrorMessage='The installer requires elevation, but elevated shell execution cannot preserve custom environment variables.'
                    }
                }

                $process.Dispose()
                $process = [System.Diagnostics.Process]::new()
                $elevatedStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
                $elevatedStartInfo.FileName = $resolvedFilePath
                $elevatedStartInfo.UseShellExecute = $true
                $elevatedStartInfo.Verb = 'runas'
                if ($null -ne $resolvedWorkingDirectory) { $elevatedStartInfo.WorkingDirectory = $resolvedWorkingDirectory }
                foreach ($argument in @($ArgumentList)) { [void]$elevatedStartInfo.ArgumentList.Add([string]$argument) }
                $process.StartInfo = $elevatedStartInfo

                try {
                    [void]$process.Start()
                    $started = $true
                }
                catch {
                    $elevatedException = $_.Exception
                    while ($null -ne $elevatedException -and $elevatedException -isnot [System.ComponentModel.Win32Exception] -and $null -ne $elevatedException.InnerException) {
                        $elevatedException = $elevatedException.InnerException
                    }

                    $elevatedNativeErrorCode = if ($elevatedException -is [System.ComponentModel.Win32Exception]) { $elevatedException.NativeErrorCode } else { $null }

                    if ($elevatedNativeErrorCode -eq 1223) {
                        return [pscustomobject][ordered]@{
                            Status='Failed'
                            FailureKind='ElevationDenied'
                            ExitCode=$null
                            StandardOutput=''
                            StandardError=''
                            DurationMilliseconds=[int][math]::Round(([System.Diagnostics.Stopwatch]::GetTimestamp() - $startTime) * 1000 / [System.Diagnostics.Stopwatch]::Frequency)
                            ErrorMessage='The installer requires elevation, and the Windows elevation prompt was cancelled or denied.'
                        }
                    }

                    return [pscustomobject][ordered]@{
                        Status='Failed'
                        FailureKind='ProcessStart'
                        ExitCode=$null
                        StandardOutput=''
                        StandardError=''
                        DurationMilliseconds=[int][math]::Round(([System.Diagnostics.Stopwatch]::GetTimestamp() - $startTime) * 1000 / [System.Diagnostics.Stopwatch]::Frequency)
                        ErrorMessage=$elevatedException.Message
                    }
                }
            }
            else {
                return [pscustomobject][ordered]@{
                    Status='Failed'
                    FailureKind='ProcessStart'
                    ExitCode=$null
                    StandardOutput=''
                    StandardError=''
                    DurationMilliseconds=[int][math]::Round(([System.Diagnostics.Stopwatch]::GetTimestamp() - $startTime) * 1000 / [System.Diagnostics.Stopwatch]::Frequency)
                    ErrorMessage=$win32Exception.Message
                }
            }
        }

        if (-not $started) {
            return [pscustomobject][ordered]@{
                Status='Failed'
                FailureKind='ProcessStart'
                ExitCode=$null
                StandardOutput=''
                StandardError=''
                DurationMilliseconds=[int][math]::Round(([System.Diagnostics.Stopwatch]::GetTimestamp() - $startTime) * 1000 / [System.Diagnostics.Stopwatch]::Frequency)
                ErrorMessage='The installer process did not start.'
            }
        }

        $stdoutTask = if ($process.StartInfo.UseShellExecute) { $null } else { $process.StandardOutput.ReadToEndAsync() }
        $stderrTask = if ($process.StartInfo.UseShellExecute) { $null } else { $process.StandardError.ReadToEndAsync() }
        $timedOut = $false
        $cancelled = $false
        $timeoutTask = [System.Threading.Tasks.Task]::Delay($TimeoutMilliseconds)
        $processExitTask = $process.WaitForExitAsync()
        try {
            if ($CancellationToken.CanBeCanceled) {
                $cancelTask = [System.Threading.Tasks.Task]::Delay([System.Threading.Timeout]::Infinite, $CancellationToken)
                $completedTask = [System.Threading.Tasks.Task]::WhenAny($processExitTask, $timeoutTask, $cancelTask).GetAwaiter().GetResult()
                if ($completedTask -eq $processExitTask) {
                } elseif ($completedTask -eq $timeoutTask) {
                    $timedOut = $true
                } elseif ($completedTask -eq $cancelTask) {
                    $cancelled = $true
                }
            } else {
                $completedTask = [System.Threading.Tasks.Task]::WhenAny($processExitTask, $timeoutTask).GetAwaiter().GetResult()
                if ($completedTask -ne $processExitTask) {
                    $timedOut = $true
                }
            }

            if ($processExitTask.IsCompleted) {
                $timedOut = $false
                $cancelled = $false
            }
        } finally {
            if (($timedOut -or $cancelled) -and -not $process.HasExited) {
                try { $process.Kill($true) } catch { }
            }
        }

        $process.WaitForExit()
        $stdout = if ($null -ne $stdoutTask) { $stdoutTask.GetAwaiter().GetResult() } else { '' }
        $stderr = if ($null -ne $stderrTask) { $stderrTask.GetAwaiter().GetResult() } else { '' }
        $duration = [int][math]::Round(([System.Diagnostics.Stopwatch]::GetTimestamp() - $startTime) * 1000 / [System.Diagnostics.Stopwatch]::Frequency)

        if ($cancelled) {
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='Cancelled'; ExitCode=$null; StandardOutput=$stdout; StandardError=$stderr; DurationMilliseconds=$duration; ErrorMessage='The installer process was cancelled.' }
        }
        if ($timedOut) {
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='Timeout'; ExitCode=$null; StandardOutput=$stdout; StandardError=$stderr; DurationMilliseconds=$duration; ErrorMessage="The installer process exceeded the $TimeoutMilliseconds millisecond timeout." }
        }
        if ($process.ExitCode -ne 0) {
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='NonZeroExit'; ExitCode=$process.ExitCode; StandardOutput=$stdout; StandardError=$stderr; DurationMilliseconds=$duration; ErrorMessage="The installer process exited with code $($process.ExitCode)." }
        }
        return [pscustomobject][ordered]@{ Status='Completed'; FailureKind=$null; ExitCode=$process.ExitCode; StandardOutput=$stdout; StandardError=$stderr; DurationMilliseconds=$duration; ErrorMessage=$null }
    }
    finally {
        $process.Dispose()
    }
}
