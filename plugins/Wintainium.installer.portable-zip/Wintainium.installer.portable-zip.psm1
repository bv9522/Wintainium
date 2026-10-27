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
    `$entryPointPath = Join-Path -Path '$escapedDestination' -ChildPath '$escapedEntryPoint'
    if (-not (Test-Path -LiteralPath `$entryPointPath -PathType Leaf)) {
        throw "Expected portable ZIP entry point was not extracted: `$entryPointPath"
    }
"@
    }

    # Expand-Archive can emit non-terminating errors. Without Stop + an explicit
    # nonzero exit, a partial extraction (for example, a locked running EXE) can
    # be reported as successful because powershell.exe itself exits with code 0.
    # Promote extraction errors to terminating errors and propagate them through
    # the process boundary so Core never records a false successful installation.
    $script = @"
`$ErrorActionPreference = 'Stop'
try {
    Expand-Archive -LiteralPath '$escapedArtifactPath' -DestinationPath '$escapedDestination' -Force -ErrorAction Stop
$entryPointCheck
    exit 0
}
catch {
    [Console]::Error.WriteLine([string]$_.Exception.Message)
    exit 1
}
"@
    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($script))

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
