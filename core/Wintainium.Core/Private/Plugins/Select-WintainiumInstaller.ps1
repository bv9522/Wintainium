function Select-WintainiumInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Artifact,

        [Parameter(Mandatory)]
        [object[]]$Plugins
    )

    $pluginId = $Manifest.installer.pluginId
    $requiredContractVersion = $Manifest.installer.requiredContractVersion
    $artifactFormat = if ($Artifact.Contains('format')) { [string]$Artifact['format'] } else { $null }

    if ([string]::IsNullOrWhiteSpace($artifactFormat)) {
        return [pscustomobject][ordered]@{
            IsSelected = $false
            InstallerPlugin = $null
            ArtifactFormat = $null
            Error = [pscustomobject]@{
                Code = 'InstallerSelectionArtifactFormatMissing'
                Message = 'Installer selection requires the selected artifact to declare a format.'
            }
        }
    }

    $resolution = Resolve-WintainiumPlugin -Plugins $Plugins -PluginId $pluginId -PluginType Installer -RequiredContractVersion $requiredContractVersion
    if (-not $resolution.IsResolved) {
        return [pscustomobject][ordered]@{
            IsSelected = $false
            InstallerPlugin = $null
            ArtifactFormat = $artifactFormat
            Error = $resolution.Error
        }
    }

    $capabilities = $resolution.Plugin.Capabilities
    $supportedFormats = @()
    if ($capabilities -is [System.Collections.IDictionary] -and $capabilities.Contains('supportedFormats')) {
        $supportedFormats = @($capabilities['supportedFormats'] | ForEach-Object {
                if ($_ -is [string]) { $_.Trim().ToLowerInvariant() }
            })
    }

    $normalizedArtifactFormat = $artifactFormat.Trim().ToLowerInvariant()

    if ($supportedFormats -notcontains $normalizedArtifactFormat) {
        return [pscustomobject][ordered]@{
            IsSelected = $false
            InstallerPlugin = $null
            ArtifactFormat = $artifactFormat
            Error = [pscustomobject]@{
                Code = 'InstallerSelectionArtifactIncompatible'
                Message = "Installer plugin '$pluginId' does not support artifact format '$artifactFormat'."
            }
        }
    }

    [pscustomobject][ordered]@{
        IsSelected = $true
        InstallerPlugin = $resolution.Plugin
        ArtifactFormat = $artifactFormat
        Error = $null
    }
}
