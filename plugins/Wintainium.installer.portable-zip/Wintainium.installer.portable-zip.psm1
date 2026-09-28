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
    if ($null -ne $entryPoint -and [string]::IsNullOrWhiteSpace([string]$entryPoint)) {
        throw 'Portable ZIP installer entryPoint cannot be empty.'
    }

    [pscustomobject][ordered]@{
        ExecutablePath = (Get-Command powershell.exe -ErrorAction Stop).Source
        Arguments = [string[]]@(
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            'Expand-Archive -LiteralPath $args[0] -DestinationPath $args[1] -Force',
            [System.IO.Path]::GetFullPath($artifactPath),
            $destination
        )
    }
}

Export-ModuleMember -Function Invoke-WintainiumInstaller
