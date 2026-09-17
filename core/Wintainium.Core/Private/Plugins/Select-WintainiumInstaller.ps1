function Select-WintainiumInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Manifest,

        [Parameter(Mandatory)]
        [psobject]$Artifact,

        [Parameter(Mandatory)]
        [object[]]$Plugins
    )

    $getValue = {
        param([object]$Object, [string]$Name)
        if ($null -eq $Object) { return $null }
        if ($Object -is [System.Collections.IDictionary]) {
            if ($Object.Contains($Name)) { return $Object[$Name] }
            return $null
        }
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) { return $property.Value }
        return $null
    }

    $installer = & $getValue $Manifest 'installer'
    $pluginId = [string](& $getValue $installer 'pluginId')
    $requiredContractVersion = [string](& $getValue $installer 'requiredContractVersion')
    $artifactFormat = [string](& $getValue $Artifact 'format')

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
