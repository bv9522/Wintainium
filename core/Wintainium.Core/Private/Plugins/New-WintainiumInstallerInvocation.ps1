function New-WintainiumInstallerInvocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Selection,
        [Parameter(Mandatory)] [psobject]$Request
    )

    if ($null -eq $Selection -or -not ($Selection.PSObject.Properties.Name -contains 'IsSelected') -or $Selection.IsSelected -ne $true) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationSelectionInvalid'; Message = 'Installer invocation requires a successful installer selection.' } }
    }
    if (-not ($Selection.PSObject.Properties.Name -contains 'InstallerPlugin') -or $null -eq $Selection.InstallerPlugin) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationPluginMissing'; Message = 'Installer invocation requires the selected installer plugin.' } }
    }
    if ($null -eq $Request -or -not ($Request.PSObject.Properties.Name -contains 'Artifact') -or $null -eq $Request.Artifact) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationArtifactMissing'; Message = 'Installer invocation requires the completed artifact handoff.' } }
    }

    $plugin = $Selection.InstallerPlugin
    $pluginId = if ($plugin.PSObject.Properties.Name -contains 'PluginId') { [string]$plugin.PluginId } else { $null }
    if ([string]::IsNullOrWhiteSpace($pluginId)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationPluginIdMissing'; Message = 'The selected installer plugin must declare a plugin identifier.' } }
    }

    $entryPoint = if ($plugin.PSObject.Properties.Name -contains 'EntryPoint') { [string]$plugin.EntryPoint } else { $null }
    $descriptorPath = if ($plugin.PSObject.Properties.Name -contains 'DescriptorPath') { [string]$plugin.DescriptorPath } else { $null }
    if ([string]::IsNullOrWhiteSpace($entryPoint)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationEntryPointMissing'; Message = 'The selected installer plugin does not declare an entryPoint.' } }
    }
    if ([string]::IsNullOrWhiteSpace($descriptorPath) -or -not [System.IO.Path]::IsPathFullyQualified($descriptorPath)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationDescriptorPathInvalid'; Message = 'The selected installer plugin must provide an absolute descriptor path.' } }
    }

    $descriptorPath = [System.IO.Path]::GetFullPath($descriptorPath)
    if (-not (Test-Path -LiteralPath $descriptorPath -PathType Leaf)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationDescriptorPathMissing'; Message = 'The selected installer plugin descriptor file was not found.' } }
    }
    if ([System.IO.Path]::IsPathFullyQualified($entryPoint) -or $entryPoint -match '(^|[\/])\.\.([\/]|$)' -or $entryPoint -match '^[\/]' -or $entryPoint -notmatch '^[^\/:*?"<>|]+\.psm1$') {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationEntryPointInvalid'; Message = 'Installer entryPoint must be a relative .psm1 path without parent-directory traversal.' } }
    }

    $pluginRoot = Split-Path -Path $descriptorPath -Parent
    $entryPointPath = Join-Path -Path $pluginRoot -ChildPath $entryPoint
    $resolvedEntryPoint = [System.IO.Path]::GetFullPath($entryPointPath)
    $resolvedRoot = [System.IO.Path]::GetFullPath($pluginRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedEntryPoint.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationEntryPointOutsidePluginRoot'; Message = 'Installer entryPoint must remain within the plugin directory.' } }
    }
    if (-not (Test-Path -LiteralPath $resolvedEntryPoint -PathType Leaf)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationEntryPointMissingFile'; Message = "Installer entryPoint '$entryPoint' was not found in the plugin directory." } }
    }

    $artifact = $Request.Artifact
    $artifactPath = if ($artifact.PSObject.Properties.Name -contains 'Path') { [string]$artifact.Path } else { $null }
    if ([string]::IsNullOrWhiteSpace($artifactPath) -or -not [System.IO.Path]::IsPathFullyQualified($artifactPath) -or -not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationArtifactPathInvalid'; Message = 'Installer invocation requires an absolute path to the completed artifact.' } }
    }

    $installer = if ($Request.PSObject.Properties.Name -contains 'Installer') { $Request.Installer } else { $null }
    $requestPluginId = if ($null -ne $installer -and $installer.PSObject.Properties.Name -contains 'pluginId') { [string]$installer.pluginId } else { $null }
    if ([string]::IsNullOrWhiteSpace($requestPluginId) -or -not $requestPluginId.Equals($pluginId, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationPluginMismatch'; Message = 'The selected installer plugin does not match the installer declared by the request.' } }
    }

    $artifactFormat = if ($Selection.PSObject.Properties.Name -contains 'ArtifactFormat') { [string]$Selection.ArtifactFormat } else { $null }
    if ([string]::IsNullOrWhiteSpace($artifactFormat)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationArtifactFormatMissing'; Message = 'Installer invocation requires the artifact format selected by the installer-selection boundary.' } }
    }

    $settings = if ($null -ne $installer -and $installer.PSObject.Properties.Name -contains 'settings') { $installer.settings } else { $null }
    if ($null -eq $settings -or ($settings -isnot [System.Collections.IDictionary] -and $settings -isnot [pscustomobject])) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationSettingsInvalid'; Message = 'Installer invocation requires structured installer settings.' } }
    }

    [pscustomobject][ordered]@{
        IsValid = $true
        Invocation = [pscustomobject][ordered]@{
            OperationId = $Request.OperationId
            DownloadOperationId = $Request.DownloadOperationId
            PluginId = $pluginId
            PluginModulePath = $resolvedEntryPoint
            ArtifactPath = [System.IO.Path]::GetFullPath($artifactPath)
            ArtifactFormat = $artifactFormat
            Settings = $settings
        }
        Error = $null
    }
}
