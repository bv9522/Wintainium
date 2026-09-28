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
            throw "MSIX installer invocation is missing required property '$propertyName'."
        }
    }

    $artifactPath = [string]$Invocation.ArtifactPath
    if ([string]::IsNullOrWhiteSpace($artifactPath) -or
        -not [System.IO.Path]::IsPathFullyQualified($artifactPath) -or
        -not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        throw 'MSIX installer requires an existing absolute artifact path.'
    }

    if (-not ([string]$Invocation.ArtifactFormat -ieq 'msix')) {
        throw "MSIX installer requires artifact format 'msix'."
    }

    $settings = $Invocation.Settings
    if ($null -eq $settings -or
        ($settings -isnot [System.Collections.IDictionary] -and $settings -isnot [pscustomobject])) {
        throw 'MSIX installer requires structured installer settings.'
    }

    $arguments = [System.Collections.Generic.List[string]]::new()
    [void]$arguments.Add('-NoProfile')
    [void]$arguments.Add('-NonInteractive')
    [void]$arguments.Add('-Command')
    [void]$arguments.Add('Add-AppxPackage -Path $args[0]')

    $argumentsToPass = [System.Collections.Generic.List[string]]::new()
    [void]$argumentsToPass.Add([System.IO.Path]::GetFullPath($artifactPath))

    $rawArguments = Get-WintainiumInstallerSetting -Settings $settings -Name 'arguments'
    if ($null -ne $rawArguments) {
        if ($rawArguments -is [string] -or
            $rawArguments -is [System.Collections.IDictionary] -or
            $rawArguments -isnot [System.Collections.IEnumerable]) {
            throw 'MSIX installer setting arguments must be an array of strings.'
        }

        $extraArguments = @($rawArguments)
        if (@($extraArguments | Where-Object { $_ -isnot [string] }).Count -gt 0) {
            throw 'MSIX installer setting arguments must contain only strings.'
        }

        foreach ($argument in $extraArguments) {
            if ([string]::IsNullOrWhiteSpace($argument)) {
                throw 'MSIX installer setting arguments must not contain empty strings.'
            }
        }

        if ($extraArguments.Count -gt 0) {
            $arguments[3] = 'Add-AppxPackage -Path $args[0] ' + ($extraArguments -join ' ')
        }
    }

    $powershell = Get-Command powershell.exe -ErrorAction Stop
    if ($null -eq $powershell -or [string]::IsNullOrWhiteSpace($powershell.Source)) {
        throw 'MSIX installer requires Windows PowerShell.'
    }

    [pscustomobject][ordered]@{
        ExecutablePath = $powershell.Source
        Arguments = [string[]]($arguments + $argumentsToPass)
    }
}

Export-ModuleMember -Function Invoke-WintainiumInstaller
