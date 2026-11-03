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


    if (-not ('WintainiumInstallerStreamCapture' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;
public sealed class WintainiumInstallerStreamCapture {
 private readonly object gate = new object(); private readonly StringBuilder retained = new StringBuilder(); private bool truncated, completed;
 public Task Worker { get; private set; }
 public void Start(StreamReader reader, int limit) { Worker = Task.Run(async () => { var b = new char[4096]; try { while (true) { int n = await reader.ReadAsync(b,0,b.Length).ConfigureAwait(false); if(n==0) { lock(gate) completed=true; break; } lock(gate) { int remaining=limit-retained.Length; if(remaining>0) retained.Append(b,0,Math.Min(remaining,n)); if(n>remaining) truncated=true; } } } catch {} }); }
 public string Text { get { lock(gate) return retained.ToString(); } }
 public bool Truncated { get { lock(gate) return truncated; } }
 public bool Completed { get { lock(gate) return completed; } }
}
'@ -ErrorAction Stop | Out-Null
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

        $stdoutCapture = $null
        $stderrCapture = $null
        if (-not $process.StartInfo.UseShellExecute) {
            $stdoutCapture = [WintainiumInstallerStreamCapture]::new()
            $stderrCapture = [WintainiumInstallerStreamCapture]::new()
            $stdoutCapture.Start($process.StandardOutput, 65536)
            $stderrCapture.Start($process.StandardError, 65536)
        }
        $timedOut = $false
        $cancelled = $false
        $terminationError = $null
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
            if ($timedOut -or $cancelled) {
                try { if (-not $process.HasExited) { $process.Kill($true) } }
                catch { $terminationError = $_.Exception.GetType().Name + ': ' + $_.Exception.Message }
                $terminationWait = [System.Threading.Tasks.Task]::WhenAny($processExitTask, [System.Threading.Tasks.Task]::Delay(5000)).GetAwaiter().GetResult()
                if ($terminationWait -ne $processExitTask -and [string]::IsNullOrWhiteSpace($terminationError)) {
                    $terminationError = 'The process did not exit within the 5000 millisecond termination grace period.'
                }
            }
        }

        if ($processExitTask.IsCompleted -and $null -ne $stdoutCapture) {
            $drainTask = [System.Threading.Tasks.Task]::WhenAll([System.Threading.Tasks.Task[]]@($stdoutCapture.Worker, $stderrCapture.Worker))
            [void][System.Threading.Tasks.Task]::WhenAny($drainTask, [System.Threading.Tasks.Task]::Delay(2000)).GetAwaiter().GetResult()
        }
        if ($null -ne $stdoutCapture -and -not $stdoutCapture.Completed) { try { $process.StandardOutput.Dispose() } catch { } }
        if ($null -ne $stderrCapture -and -not $stderrCapture.Completed) { try { $process.StandardError.Dispose() } catch { } }
        if ($null -ne $stdoutCapture -and -not $stdoutCapture.Completed) { [void][System.Threading.Tasks.Task]::WhenAny($stdoutCapture.Worker, [System.Threading.Tasks.Task]::Delay(250)).GetAwaiter().GetResult() }
        if ($null -ne $stderrCapture -and -not $stderrCapture.Completed) { [void][System.Threading.Tasks.Task]::WhenAny($stderrCapture.Worker, [System.Threading.Tasks.Task]::Delay(250)).GetAwaiter().GetResult() }
        $stdout = if ($null -ne $stdoutCapture) { $stdoutCapture.Text } else { '' }
        $stderr = if ($null -ne $stderrCapture) { $stderrCapture.Text } else { '' }
        $stdoutTruncated = $null -ne $stdoutCapture -and $stdoutCapture.Truncated
        $stderrTruncated = $null -ne $stderrCapture -and $stderrCapture.Truncated
        $stdoutComplete = $null -eq $stdoutCapture -or $stdoutCapture.Completed
        $stderrComplete = $null -eq $stderrCapture -or $stderrCapture.Completed
        $duration = [int][math]::Round(([System.Diagnostics.Stopwatch]::GetTimestamp() - $startTime) * 1000 / [System.Diagnostics.Stopwatch]::Frequency)

        if ($cancelled) {
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='Cancelled'; ExitCode=$null; StandardOutput=$stdout; StandardError=$stderr; DurationMilliseconds=$duration; StandardOutputTruncated=$stdoutTruncated; StandardErrorTruncated=$stderrTruncated; StandardOutputComplete=$stdoutComplete; StandardErrorComplete=$stderrComplete; TerminationError=$terminationError; ErrorMessage='The installer process was cancelled.' }
        }
        if ($timedOut) {
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='Timeout'; ExitCode=$null; StandardOutput=$stdout; StandardError=$stderr; DurationMilliseconds=$duration; StandardOutputTruncated=$stdoutTruncated; StandardErrorTruncated=$stderrTruncated; StandardOutputComplete=$stdoutComplete; StandardErrorComplete=$stderrComplete; TerminationError=$terminationError; ErrorMessage="The installer process exceeded the $TimeoutMilliseconds millisecond timeout." }
        }
        if ($processExitTask.IsCompleted -and $process.ExitCode -eq 1223) {
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='ElevationDenied'; ExitCode=$process.ExitCode; StandardOutput=$stdout; StandardError=$stderr; DurationMilliseconds=$duration; StandardOutputTruncated=$stdoutTruncated; StandardErrorTruncated=$stderrTruncated; StandardOutputComplete=$stdoutComplete; StandardErrorComplete=$stderrComplete; TerminationError=$terminationError; ErrorMessage='The Windows elevation prompt was cancelled or denied.' }
        }
        if (-not $processExitTask.IsCompleted) {
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='TerminationFailed'; ExitCode=$null; StandardOutput=$stdout; StandardError=$stderr; DurationMilliseconds=$duration; StandardOutputTruncated=$stdoutTruncated; StandardErrorTruncated=$stderrTruncated; StandardOutputComplete=$stdoutComplete; StandardErrorComplete=$stderrComplete; TerminationError=$terminationError; ErrorMessage=if ($terminationError) { $terminationError } else { 'The installer process did not terminate within the allowed grace period.' } }
        }
        if ($process.ExitCode -ne 0) {
            return [pscustomobject][ordered]@{ Status='Failed'; FailureKind='NonZeroExit'; ExitCode=$process.ExitCode; StandardOutput=$stdout; StandardError=$stderr; DurationMilliseconds=$duration; StandardOutputTruncated=$stdoutTruncated; StandardErrorTruncated=$stderrTruncated; StandardOutputComplete=$stdoutComplete; StandardErrorComplete=$stderrComplete; TerminationError=$terminationError; ErrorMessage="The installer process exited with code $($process.ExitCode)." }
        }
        return [pscustomobject][ordered]@{ Status='Completed'; FailureKind=$null; ExitCode=$process.ExitCode; StandardOutput=$stdout; StandardError=$stderr; DurationMilliseconds=$duration; StandardOutputTruncated=$stdoutTruncated; StandardErrorTruncated=$stderrTruncated; StandardOutputComplete=$stdoutComplete; StandardErrorComplete=$stderrComplete; TerminationError=$terminationError; ErrorMessage=$null }
    }
    finally {
        $process.Dispose()
    }
}
