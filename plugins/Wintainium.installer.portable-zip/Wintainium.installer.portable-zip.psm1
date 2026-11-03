function Get-WintainiumInstallerSetting {
    param(
        [Parameter(Mandatory)] [object]$Settings,
        [Parameter(Mandatory)] [string]$Name
    )

    if ($Settings -is [System.Collections.IDictionary]) {
        if ($Settings.Contains($Name)) { return $Settings[$Name] }
        return $null
    }

    $property = $Settings.PSObject.Properties[$Name]
    if ($null -ne $property) { return $property.Value }
    return $null
}

function Invoke-WintainiumInstaller {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object]$Invocation)

    foreach ($propertyName in @('ArtifactPath','ArtifactFormat','Settings')) {
        if (-not ($Invocation.PSObject.Properties.Name -contains $propertyName)) {
            throw "Portable ZIP installer invocation is missing required property '$propertyName'."
        }
    }

    $artifactPath = [string]$Invocation.ArtifactPath
    if ([string]::IsNullOrWhiteSpace($artifactPath) -or
        -not [System.IO.Path]::IsPathFullyQualified($artifactPath) -or
        -not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        throw 'Portable ZIP installer requires an existing absolute artifact path.'
    }

    if (-not ([string]$Invocation.ArtifactFormat -ieq 'zip')) {
        throw "Portable ZIP installer requires artifact format 'zip'."
    }

    $settings = $Invocation.Settings
    if ($null -eq $settings -or
        ($settings -isnot [System.Collections.IDictionary] -and $settings -isnot [pscustomobject])) {
        throw 'Portable ZIP installer requires structured installer settings.'
    }

    $destination = Get-WintainiumInstallerSetting -Settings $settings -Name 'destinationPath'
    if ([string]::IsNullOrWhiteSpace([string]$destination) -or
        -not [System.IO.Path]::IsPathFullyQualified([string]$destination)) {
        throw 'Portable ZIP installer requires an absolute destinationPath setting.'
    }
    $destination = [System.IO.Path]::GetFullPath([string]$destination)

    $entryPoint = Get-WintainiumInstallerSetting -Settings $settings -Name 'entryPoint'
    if ($null -ne $entryPoint) {
        $entryPoint = [string]$entryPoint
        if ([string]::IsNullOrWhiteSpace($entryPoint) -or
            [System.IO.Path]::IsPathFullyQualified($entryPoint) -or
            $entryPoint -match '(^|[\\/])\.\.([\\/]|$)') {
            throw 'Portable ZIP installer entryPoint must be a non-empty relative path without parent-directory traversal.'
        }
    }

    if ([string]::IsNullOrWhiteSpace($env:WINDIR)) {
        throw 'Portable ZIP installer requires the Windows directory environment variable.'
    }

    $powershellPath = Join-Path -Path $env:WINDIR -ChildPath 'System32/WindowsPowerShell/v1.0/powershell.exe'
    if (-not [System.IO.Path]::IsPathFullyQualified($powershellPath) -or
        -not (Test-Path -LiteralPath $powershellPath -PathType Leaf)) {
        throw 'Portable ZIP installer could not locate the Windows PowerShell executable.'
    }

    # Windows PowerShell's -Command mode does not reliably expose trailing
    # process arguments through $args in this invocation shape. Embed validated
    # absolute paths as escaped PowerShell single-quoted literals in an encoded
    # command, avoiding both the empty-$args failure and command injection.
    $resolvedArtifactPath = [System.IO.Path]::GetFullPath($artifactPath)
    $escapedArtifactPath = $resolvedArtifactPath.Replace("'", "''")
    $escapedDestination = $destination.Replace("'", "''")
    $entryPointCheck = ''
    if ($null -ne $entryPoint) {
        $escapedEntryPoint = $entryPoint.Replace("'", "''")
        $entryPointCheck = @"
    `$entryPointPath = [System.IO.Path]::GetFullPath((Join-Path -Path '$escapedDestination' -ChildPath '$escapedEntryPoint'))
    if (-not (Test-Path -LiteralPath `$entryPointPath -PathType Leaf)) {
        throw "Expected portable ZIP entry point was not extracted: `$entryPointPath"
    }
"@
    }

    # Avoid Expand-Archive: Windows PowerShell can discover the
    # Microsoft.PowerShell.Archive module but fail to load it on some hosts.
    # Extract through .NET compression APIs, reject ZIP path traversal, and
    # use FileMode.Create to replace existing files during updates.
    $entryPointCheck = ''
    if ($null -ne $entryPoint) {
        $escapedEntryPoint = $entryPoint.Replace("'", "''")
        $entryPointCheck = @"
    `$entryPointPath = [System.IO.Path]::GetFullPath((Join-Path -Path `$stagePath -ChildPath '$escapedEntryPoint'))
    if (-not `$entryPointPath.StartsWith(`$stagePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or -not [System.IO.File]::Exists(`$entryPointPath)) {
        throw 'Expected portable ZIP entry point was not extracted into staging.'
    }
"@
    }

    $script = @"
`$ErrorActionPreference = 'Stop'
`$destinationRoot = [System.IO.Path]::GetFullPath('$escapedDestination').TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
`$parentDirectory = [System.IO.Path]::GetDirectoryName(`$destinationRoot)
if ([string]::IsNullOrWhiteSpace(`$parentDirectory) -or [string]::Equals(`$parentDirectory, `$destinationRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Portable ZIP destination must be a directory below a filesystem root.'
}
[System.IO.Directory]::CreateDirectory(`$parentDirectory) | Out-Null
`$operationToken = [guid]::NewGuid().ToString('N')
`$destinationName = [System.IO.Path]::GetFileName(`$destinationRoot)
`$stagePath = Join-Path `$parentDirectory ('.' + `$destinationName + '.wintanium-stage-' + `$operationToken)
`$backupPath = Join-Path `$parentDirectory ('.' + `$destinationName + '.wintanium-backup-' + `$operationToken)
`$backupCreated = [System.Boolean]::False
`$stageCreated = [System.Boolean]::False
try {
    [System.IO.Directory]::CreateDirectory(`$stagePath) | Out-Null
    `$stageCreated = [System.Boolean]::True
    # Preserve overlay semantics, but never follow links in the old installation.
    if ([System.IO.Directory]::Exists(`$destinationRoot)) {
        `$pendingDirectories = [System.Collections.Generic.Stack[string]]::new()
        `$pendingDirectories.Push(`$destinationRoot)
        while (`$pendingDirectories.Count -gt 0) {
            `$sourceDirectory = `$pendingDirectories.Pop()
            `$relativeDirectory = `$sourceDirectory.Substring(`$destinationRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar).Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            `$targetDirectory = if ([string]::IsNullOrEmpty(`$relativeDirectory)) { `$stagePath } else { Join-Path `$stagePath `$relativeDirectory }
            [System.IO.Directory]::CreateDirectory(`$targetDirectory) | Out-Null
            foreach (`$directory in [System.IO.Directory]::EnumerateDirectories(`$sourceDirectory)) {
                `$directoryInfo = [System.IO.DirectoryInfo]::new(`$directory)
                if ((`$directoryInfo.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Existing installation contains a reparse point: `$directory" }
                `$pendingDirectories.Push(`$directory)
            }
            foreach (`$file in [System.IO.Directory]::EnumerateFiles(`$sourceDirectory)) {
                `$fileInfo = [System.IO.FileInfo]::new(`$file)
                if ((`$fileInfo.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Existing installation contains a reparse point: `$file" }
                `$relativeFile = `$file.Substring(`$destinationRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar).Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
                `$targetFile = Join-Path `$stagePath `$relativeFile
                [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName(`$targetFile)) | Out-Null
                [System.IO.File]::Copy(`$file, `$targetFile, [System.Boolean]::True)
            }
        }
    }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    `$archive = [System.IO.Compression.ZipFile]::OpenRead('$escapedArtifactPath')
    try {
        foreach (`$entry in `$archive.Entries) {
            `$relativePath = `$entry.FullName.Replace('/', [System.IO.Path]::DirectorySeparatorChar).Replace([char]92, [System.IO.Path]::DirectorySeparatorChar)
            if ([string]::IsNullOrWhiteSpace(`$relativePath)) { continue }
            if (`$relativePath.Contains(':') -or `$relativePath.Contains([char]0)) { throw "ZIP entry contains an invalid path: `$((`$entry).FullName)" }
            `$targetPath = [System.IO.Path]::GetFullPath((Join-Path -Path `$stagePath -ChildPath `$relativePath))
            `$stagePrefix = `$stagePath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
            if (-not `$targetPath.StartsWith(`$stagePrefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw "ZIP entry attempts to write outside destination: `$((`$entry).FullName)" }
            if (`$entry.FullName.EndsWith('/') -or `$entry.FullName.EndsWith([string][char]92)) { [System.IO.Directory]::CreateDirectory(`$targetPath) | Out-Null; continue }
            [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName(`$targetPath)) | Out-Null
            `$inputStream = `$entry.Open()
            try {
                `$outputStream = [System.IO.File]::Open(`$targetPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                try { `$inputStream.CopyTo(`$outputStream) } finally { `$outputStream.Dispose() }
            } finally { `$inputStream.Dispose() }
        }
    } finally { `$archive.Dispose() }
`$entryPointCheck
    if ([System.IO.Directory]::Exists(`$destinationRoot)) { [System.IO.Directory]::Move(`$destinationRoot, `$backupPath); `$backupCreated = [System.Boolean]::True }
    try {
        [System.IO.Directory]::Move(`$stagePath, `$destinationRoot)
        `$stageCreated = [System.Boolean]::False
    } catch {
        `$activationError = `$_.Exception.Message
        if (`$backupCreated -and -not [System.IO.Directory]::Exists(`$destinationRoot)) {
            try { [System.IO.Directory]::Move(`$backupPath, `$destinationRoot); `$backupCreated = [System.Boolean]::False }
            catch { throw ('Activation failed and rollback failed. Original installation remains at ''{0}''. Activation: {1}. Rollback: {2}' -f `$backupPath, `$activationError, `$_.Exception.Message) }
        }
        throw
    }
    if (`$backupCreated) {
        try { [System.IO.Directory]::Delete(`$backupPath, [System.Boolean]::True); `$backupCreated = [System.Boolean]::False }
        catch { [Console]::Error.WriteLine("Installation succeeded, but previous installation backup remains at: `$backupPath") }
    }
    exit 0
} catch {
    `$message = [string]`$_.Exception.Message
    if (`$backupCreated -and [System.IO.Directory]::Exists(`$backupPath) -and -not [System.IO.Directory]::Exists(`$destinationRoot)) { `$message += " Original installation remains recoverable at: `$backupPath" }
    [Console]::Error.WriteLine(`$message)
    exit 1
} finally {
    if (`$stageCreated -and [System.IO.Directory]::Exists(`$stagePath)) {
        try { [System.IO.Directory]::Delete(`$stagePath, [System.Boolean]::True) } catch { [Console]::Error.WriteLine("Temporary staging directory could not be removed: `$stagePath") }
    }
}
"@
    # Portable applications may be installed under protected locations such as
    # Program Files. Run those extractions through a tracked elevated child
    # process; the parent waits for its exit code and relays extraction errors
    # from a temporary diagnostic file to Core.
    $protectedRoots = @(
        $env:ProgramFiles,
        [Environment]::GetEnvironmentVariable('ProgramFiles(x86)'),
        $env:WINDIR,
        $env:ProgramData
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    $requiresElevation = $false
    foreach ($protectedRoot in $protectedRoots) {
        try {
            $normalizedRoot = [System.IO.Path]::GetFullPath([string]$protectedRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            $normalizedPrefix = $normalizedRoot + [System.IO.Path]::DirectorySeparatorChar
            if ([string]::Equals($destination, $normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
                $destination.StartsWith($normalizedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $requiresElevation = $true
                break
            }
        }
        catch {
            # An invalid environment path is ignored; the remaining roots still
            # protect the common Windows installation locations.
        }
    }

    if ($requiresElevation) {
        # Start-Process cannot combine redirected streams with -Verb RunAs.
        # Write extraction errors to a temp diagnostic file for the parent.
        $diagnosticPath = Join-Path ([System.IO.Path]::GetTempPath()) ('wintanium-zip-' + [guid]::NewGuid().ToString('N') + '.stderr')
        $escapedDiagnosticPath = $diagnosticPath.Replace("'", "''")
        $script = $script.Replace(
            "[Console]::Error.WriteLine(`$message)",
            "[System.IO.File]::WriteAllText('$escapedDiagnosticPath', `$message)"
        )
        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($script))
        $escapedPowerShellPath = $powershellPath.Replace("'", "''")
        $wrapper = @"
`$ErrorActionPreference = 'Stop'
`$powerShellPath = '$escapedPowerShellPath'
`$childCommand = '$encodedCommand'
`$stderrPath = '$escapedDiagnosticPath'
try {
    `$childArguments = @('-NoProfile', '-NonInteractive', '-EncodedCommand', `$childCommand)
    `$child = Start-Process -FilePath `$powerShellPath -ArgumentList `$childArguments -Verb RunAs -Wait -PassThru
    if (Test-Path -LiteralPath `$stderrPath -PathType Leaf) { [Console]::Error.Write([System.IO.File]::ReadAllText(`$stderrPath)) }
    exit [int]`$child.ExitCode
}
catch {
    `$exception = `$_.Exception
    while (`$null -ne `$exception -and `$exception -isnot [System.ComponentModel.Win32Exception] -and `$null -ne `$exception.InnerException) { `$exception = `$exception.InnerException }
    if (`$exception -is [System.ComponentModel.Win32Exception] -and `$exception.NativeErrorCode -eq 1223) {
        [Console]::Error.WriteLine('ElevationDenied: The Windows elevation prompt was cancelled or denied.')
        exit 1223
    }
    [Console]::Error.WriteLine([string]`$_.Exception.Message)
    exit 1
}
finally {
    Remove-Item -LiteralPath `$stderrPath -Force -ErrorAction SilentlyContinue
}
"@
        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($wrapper))
    }
    else {
        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($script))
    }

    [pscustomobject][ordered]@{
        ExecutablePath = [System.IO.Path]::GetFullPath($powershellPath)
        Arguments = [string[]]@(
            '-NoProfile',
            '-NonInteractive',
            '-EncodedCommand',
            $encodedCommand
        )
    }
}

Export-ModuleMember -Function Invoke-WintainiumInstaller
