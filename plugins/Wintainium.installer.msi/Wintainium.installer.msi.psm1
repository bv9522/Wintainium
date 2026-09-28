function Get-WintainiumInstallerSetting {
    param(
        [Parameter(Mandatory)]
        [object]$Settings,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($Settings -is [System.Collections.IDictionary]) {
        if ($Settings.Contains($Name)) {
            return $Settings[$Name]
        }

        return $null
    }

    $property = $Settings.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }

    return $null
}

function Invoke-WintainiumInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Invocation
    )

    foreach ($propertyName in @('ArtifactPath', 'ArtifactFormat', 'Settings')) {
        if (-not ($Invocation.PSObject.Properties.Name -contains $propertyName)) {
            throw "MSI installer invocation is missing required property '$propertyName'."
        }
    }

    $artifactPath = [string]$Invocation.ArtifactPath
    if ([string]::IsNullOrWhiteSpace($artifactPath) -or
        -not [System.IO.Path]::IsPathFullyQualified($artifactPath) -or
        -not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        throw 'MSI installer requires an existing absolute artifact path.'
    }

    if (-not ([string]$Invocation.ArtifactFormat -ieq 'msi')) {
        throw "MSI installer requires artifact format 'msi'."
    }

    $settings = $Invocation.Settings
    if ($null -eq $settings -or
        ($settings -isnot [System.Collections.IDictionary] -and $settings -isnot [pscustomobject])) {
        throw 'MSI installer requires structured installer settings.'
    }

    $arguments = @('/i', [System.IO.Path]::GetFullPath($artifactPath))
    $rawArguments = Get-WintainiumInstallerSetting -Settings $settings -Name 'arguments'

    if ($null -ne $rawArguments) {
        if ($rawArguments -is [string] -or
            $rawArguments -is [System.Collections.IDictionary] -or
            $rawArguments -isnot [System.Collections.IEnumerable]) {
            throw 'MSI installer setting arguments must be an array of strings.'
        }

        $extraArguments = @($rawArguments)
        if (@($extraArguments | Where-Object { $_ -isnot [string] }).Count -gt 0) {
            throw 'MSI installer setting arguments must contain only strings.'
        }

        $arguments += [string[]]$extraArguments
    }

    $windowsDirectory = $env:WINDIR
    if ([string]::IsNullOrWhiteSpace($windowsDirectory)) {
        throw 'MSI installer requires the Windows directory environment variable.'
    }

    $msiexecPath = Join-Path -Path $windowsDirectory -ChildPath 'System32/msiexec.exe'
    if (-not [System.IO.Path]::IsPathFullyQualified($msiexecPath) -or
        -not (Test-Path -LiteralPath $msiexecPath -PathType Leaf)) {
        throw 'MSI installer could not locate the Windows Installer executable.'
    }

    [pscustomobject][ordered]@{
        ExecutablePath = [System.IO.Path]::GetFullPath($msiexecPath)
        Arguments = [string[]]$arguments
    }
}

Export-ModuleMember -Function Invoke-WintainiumInstaller
