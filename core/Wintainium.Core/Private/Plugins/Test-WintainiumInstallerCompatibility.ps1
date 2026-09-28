function Test-WintainiumInstallerCompatibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Manifest,

        [Parameter(Mandatory)]
        [object]$InstallerPlugin
    )

    $supportedFormats = @($InstallerPlugin.Capabilities.supportedFormats | ForEach-Object {
        if ($_ -is [string]) { $_.Trim().ToLowerInvariant() }
    })
    $requestedFormats = @($Manifest.artifact.formats | ForEach-Object {
        if ($_ -is [string]) { $_.Trim().ToLowerInvariant() }
    })
    $matchingFormat = @($requestedFormats | Where-Object { $_ -in $supportedFormats }) | Select-Object -First 1

    if ($null -eq $matchingFormat) {
        return [pscustomobject]@{
            IsCompatible = $false
            Error = [pscustomobject]@{
                Code = 'InstallerArtifactIncompatible'
                Message = "Installer plugin '$($InstallerPlugin.PluginId)' supports none of the manifest's requested artifact formats."
            }
        }
    }

    [pscustomobject]@{
        IsCompatible = $true
        Error = $null
    }
}
