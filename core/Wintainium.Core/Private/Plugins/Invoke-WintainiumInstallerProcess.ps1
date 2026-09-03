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

        try { [void]$process.Start() }
        catch {
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='ProcessStart'; ExitCode=$null; StandardOutput=''; StandardError=''; DurationMilliseconds=[int][math]::Round(([System.Diagnostics.Stopwatch]::GetTimestamp() - $startTime) * 1000 / [System.Diagnostics.Stopwatch]::Frequency); ErrorMessage=$_.Exception.Message }
        }

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $timedOut = $false
        $cancelled = $false
        $timeoutTask = [System.Threading.Tasks.Task]::Delay($TimeoutMilliseconds)
        try {
            if ($CancellationToken.CanBeCanceled) {
                $cancelTask = [System.Threading.Tasks.Task]::Delay([System.Threading.Timeout]::Infinite, $CancellationToken)
                $completedTask = [System.Threading.Tasks.Task]::WhenAny($process.WaitForExitAsync(), $timeoutTask, $cancelTask).GetAwaiter().GetResult()
                if ($completedTask -eq $timeoutTask) { $timedOut = $true }
                elseif ($completedTask -eq $cancelTask) { $cancelled = $true }
            } else {
                $completedTask = [System.Threading.Tasks.Task]::WhenAny($process.WaitForExitAsync(), $timeoutTask).GetAwaiter().GetResult()
                if ($completedTask -eq $timeoutTask) { $timedOut = $true }
            }
        } finally {
            if (($timedOut -or $cancelled) -and -not $process.HasExited) {
                try { $process.Kill($true) } catch { }
            }
        }

        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
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
