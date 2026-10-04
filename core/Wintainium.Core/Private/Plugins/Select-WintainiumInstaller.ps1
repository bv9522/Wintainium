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
    $artifactFormat = [string](& $getValue $Artifact 'format')

    if ([string]::IsNullOrWhiteSpace($artifactFormat)) {
        return [pscustomobject][ordered]@{
            IsSelected = $false
            InstallerPlugin = $null
            ArtifactFormat = $null
            InstallationMode = $null
            Error = [pscustomobject]@{
                Code = 'InstallerSelectionArtifactFormatMissing'
                Message = 'Installer selection requires the selected artifact to declare a format.'
            }
        }
    }

    $candidates = [System.Collections.Generic.List[object]]::new()
    $candidates.Add($installer)
    foreach ($fallback in @(& $getValue $installer 'fallbacks')) {
        $candidates.Add($fallback)
    }

    $selectionErrors = [System.Collections.Generic.List[object]]::new()
    foreach ($candidate in $candidates) {
        $pluginId = [string](& $getValue $candidate 'pluginId')
        $requiredContractVersion = [string](& $getValue $candidate 'requiredContractVersion')
        $resolution = Resolve-WintainiumPlugin -Plugins $Plugins -PluginId $pluginId -PluginType Installer -RequiredContractVersion $requiredContractVersion
        if (-not $resolution.IsResolved) {
            $selectionErrors.Add($resolution.Error)
            continue
        }

        $capabilities = $resolution.Plugin.Capabilities
        $installationMode = 'process'
        if ($capabilities -is [System.Collections.IDictionary] -and $capabilities.Contains('installationMode') -and -not [string]::IsNullOrWhiteSpace([string]$capabilities['installationMode'])) {
            $installationMode = ([string]$capabilities['installationMode']).Trim().ToLowerInvariant()
        }

        $supportedFormats = @()
        if ($capabilities -is [System.Collections.IDictionary] -and $capabilities.Contains('supportedFormats')) {
            $supportedFormats = @($capabilities['supportedFormats'] | ForEach-Object {
                if ($_ -is [string]) { $_.Trim().ToLowerInvariant() }
            })
        }

        $normalizedArtifactFormat = $artifactFormat.Trim().ToLowerInvariant()
        if ($supportedFormats -contains $normalizedArtifactFormat) {
            return [pscustomobject][ordered]@{
                IsSelected = $true
                InstallerPlugin = $resolution.Plugin
                ArtifactFormat = $artifactFormat
                InstallationMode = $installationMode
                Error = $null
            }
        }
    }

    $message = "No declared installer candidate supports artifact format '$artifactFormat'."
    if ($selectionErrors.Count -gt 0) {
        $message = "$message One or more declared installer candidates could not be resolved."
    }
    [pscustomobject][ordered]@{
        IsSelected = $false
        InstallerPlugin = $null
        ArtifactFormat = $artifactFormat
        InstallationMode = $null
        Error = [pscustomobject]@{
            Code = 'InstallerSelectionArtifactIncompatible'
            Message = $message
            CandidateErrors = $selectionErrors.ToArray()
        }
    }
    [pscustomobject][ordered]@{
        IsSelected = $true
        InstallerPlugin = $resolution.Plugin
        ArtifactFormat = $artifactFormat
        InstallationMode = $installationMode
        Error = $null
    }
}
