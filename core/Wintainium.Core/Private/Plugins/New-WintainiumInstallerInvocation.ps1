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

    $plugin = $Selection.InstallerPlugin
    $pluginId = [string](& $getValue $plugin 'PluginId')
    if ([string]::IsNullOrWhiteSpace($pluginId)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationPluginIdMissing'; Message = 'The selected installer plugin must declare a plugin identifier.' } }
    }

    $entryPoint = [string](& $getValue $plugin 'EntryPoint')
    $descriptorPath = [string](& $getValue $plugin 'DescriptorPath')
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

    $entryPointHasPathSeparator = $entryPoint.Contains([char]92) -or $entryPoint.Contains([char]47)
    if ([System.IO.Path]::IsPathFullyQualified($entryPoint) -or $entryPointHasPathSeparator -or $entryPoint -notmatch '^[^:*?"<>|]+\.psm1$') {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationEntryPointInvalid'; Message = 'Installer entryPoint must be a relative .psm1 file name without path separators or parent-directory traversal.' } }
    }

    $artifact = $Request.Artifact
    $artifactPath = [string](& $getValue $artifact 'Path')
    if ([string]::IsNullOrWhiteSpace($artifactPath) -or -not [System.IO.Path]::IsPathFullyQualified($artifactPath) -or -not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationArtifactPathInvalid'; Message = 'Installer invocation requires an absolute path to the completed artifact.' } }
    }

    $installer = & $getValue $Request 'Installer'
    $requestPluginId = [string](& $getValue $installer 'pluginId')
    if ([string]::IsNullOrWhiteSpace($requestPluginId) -or -not $requestPluginId.Equals($pluginId, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationPluginMismatch'; Message = 'The selected installer plugin does not match the installer declared by the request.' } }
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

    $descriptorResult = Test-WintainiumPluginDescriptor -DescriptorPath $descriptorPath
    if (-not $descriptorResult.IsValid -or $null -eq $descriptorResult.Descriptor) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationDescriptorInvalid'; Message = 'The selected installer plugin descriptor is invalid.' } }
    }

    $descriptor = $descriptorResult.Descriptor
    $descriptorPluginId = [string](& $getValue $descriptor 'pluginId')
    $descriptorPluginType = [string](& $getValue $descriptor 'pluginType')
    $descriptorEntryPoint = [string](& $getValue $descriptor 'entryPoint')
    if (-not $descriptorPluginId.Equals($pluginId, [System.StringComparison]::OrdinalIgnoreCase) -or
        $descriptorPluginType -ne 'Installer') {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationDescriptorMismatch'; Message = 'The selected installer plugin does not match its descriptor identity.' } }
    }
    if (-not $descriptorEntryPoint.Equals($entryPoint, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject][ordered]@{ Code = 'InstallerInvocationDescriptorMismatch'; Message = 'The selected installer plugin entryPoint does not match its descriptor.' } }
    }

    $artifactFormat = [string](& $getValue $Selection 'ArtifactFormat')
    if ([string]::IsNullOrWhiteSpace($artifactFormat)) {
        return [pscustomobject][ordered]@{ IsValid = $false; Invocation = $null; Error = [pscustomobject]@{ Code = 'InstallerInvocationArtifactFormatMissing'; Message = 'Installer invocation requires the artifact format selected by the installer-selection boundary.' } }
    }

    $settings = & $getValue $installer 'settings'
    $installationMode = [string](& $getValue $Selection 'InstallationMode')
    if ([string]::IsNullOrWhiteSpace($installationMode)) {
        $installationMode = 'process'
    } else {
        $installationMode = $installationMode.Trim().ToLowerInvariant()
    }
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
            InstallationMode = $installationMode
            Settings = $settings
        }
        Error = $null
    }
}
