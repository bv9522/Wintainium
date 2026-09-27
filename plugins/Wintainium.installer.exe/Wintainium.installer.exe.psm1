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
            throw "EXE installer invocation is missing required property '$propertyName'."
        }
    }

    $artifactPath = [string]$Invocation.ArtifactPath
    if ([string]::IsNullOrWhiteSpace($artifactPath) -or
        -not [System.IO.Path]::IsPathFullyQualified($artifactPath) -or
        -not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        throw 'EXE installer requires an existing absolute artifact path.'
    }

    if (-not [string]$Invocation.ArtifactFormat -ieq 'exe') {
        throw "EXE installer requires artifact format 'exe'."
    }

    $settings = $Invocation.Settings
    if ($null -eq $settings -or
        ($settings -isnot [System.Collections.IDictionary] -and $settings -isnot [pscustomobject])) {
        throw 'EXE installer requires structured installer settings.'
    }

    $arguments = @()
    $rawArguments = Get-WintainiumInstallerSetting -Settings $settings -Name 'arguments'

    if ($null -ne $rawArguments) {
        if ($rawArguments -is [string] -or
            $rawArguments -is [System.Collections.IDictionary] -or
            $rawArguments -isnot [System.Collections.IEnumerable]) {
            throw 'EXE installer setting arguments must be an array of strings.'
        }

        $arguments = @($rawArguments)
        if (@($arguments | Where-Object { $_ -isnot [string] }).Count -gt 0) {
            throw 'EXE installer setting arguments must contain only strings.'
        }
    }

    [pscustomobject][ordered]@{
        ExecutablePath = [System.IO.Path]::GetFullPath($artifactPath)
        Arguments = [string[]]$arguments
    }
}

Export-ModuleMember -Function Invoke-WintainiumInstaller
