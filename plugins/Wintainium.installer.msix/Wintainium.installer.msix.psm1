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

    $settingsJson = ConvertTo-Json -InputObject $settings -Compress -Depth 20

    [pscustomobject][ordered]@{
        ExecutablePath = $powershell.Path
        Arguments = [string[]]@(
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            '$settings = $args[1] | ConvertFrom-Json -AsHashtable; Add-AppxPackage -Path $args[0] @settings',
            [System.IO.Path]::GetFullPath($artifactPath),
            $settingsJson
        )
    }
}

Export-ModuleMember -Function Invoke-WintainiumInstaller
