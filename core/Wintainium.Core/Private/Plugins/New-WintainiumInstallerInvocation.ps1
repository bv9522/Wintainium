function New-WintainiumInstallerInvocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Selection,

        [Parameter(Mandatory)]
        [psobject]$Request
    )

    if ($null -eq $Selection -or -not ($Selection.PSObject.Properties.Name -contains 'IsSelected') -or $Selection.IsSelected -ne $true) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Invocation = $null
            Error = [pscustomobject]@{
                Code = 'InstallerInvocationSelectionInvalid'
                Message = 'Installer invocation requires a successful installer selection.'
            }
        }
    }

    if (-not ($Selection.PSObject.Properties.Name -contains 'InstallerPlugin') -or $null -eq $Selection.InstallerPlugin) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Invocation = $null
            Error = [pscustomobject]@{
                Code = 'InstallerInvocationPluginMissing'
                Message = 'Installer invocation requires the selected installer plugin.'
            }
        }
    }

    if ($null -eq $Request -or -not ($Request.PSObject.Properties.Name -contains 'Artifact') -or $null -eq $Request.Artifact) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Invocation = $null
            Error = [pscustomobject]@{
                Code = 'InstallerInvocationArtifactMissing'
                Message = 'Installer invocation requires the completed artifact handoff.'
            }
        }
    }

    $plugin = $Selection.InstallerPlugin
    $entryPoint = if ($plugin.PSObject.Properties.Name -contains 'EntryPoint') { [string]$plugin.EntryPoint } else { $null }
    $descriptorPath = if ($plugin.PSObject.Properties.Name -contains 'DescriptorPath') { [string]$plugin.DescriptorPath } else { $null }

    if ([string]::IsNullOrWhiteSpace($entryPoint)) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Invocation = $null
            Error = [pscustomobject]@{
                Code = 'InstallerInvocationEntryPointMissing'
                Message = 'The selected installer plugin does not declare an entryPoint.'
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($descriptorPath) -or -not [System.IO.Path]::IsPathFullyQualified($descriptorPath)) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Invocation = $null
            Error = [pscustomobject]@{
                Code = 'InstallerInvocationDescriptorPathInvalid'
                Message = 'The selected installer plugin must provide an absolute descriptor path.'
            }
        }
    }

    if ([System.IO.Path]::IsPathFullyQualified($entryPoint) -or
        $entryPoint -match '(^|[\\/])\.\.([\\/]|$)' -or
        $entryPoint -match '^[\\/]' -or
        $entryPoint -notmatch '^[^\\/:*?"<>|]+\.psm1$') {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Invocation = $null
            Error = [pscustomobject]@{
                Code = 'InstallerInvocationEntryPointInvalid'
                Message = 'Installer entryPoint must be a relative .psm1 path without parent-directory traversal.'
            }
        }
    }

    $pluginRoot = Split-Path -Path $descriptorPath -Parent
    $entryPointPath = Join-Path -Path $pluginRoot -ChildPath $entryPoint
    $resolvedEntryPoint = [System.IO.Path]::GetFullPath($entryPointPath)
    $resolvedRoot = [System.IO.Path]::GetFullPath($pluginRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if (-not $resolvedEntryPoint.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Invocation = $null
            Error = [pscustomobject]@{
                Code = 'InstallerInvocationEntryPointOutsidePluginRoot'
                Message = 'Installer entryPoint must remain within the plugin directory.'
            }
        }
    }

    if (-not (Test-Path -LiteralPath $resolvedEntryPoint -PathType Leaf)) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Invocation = $null
            Error = [pscustomobject]@{
                Code = 'InstallerInvocationEntryPointMissingFile'
                Message = "Installer entryPoint '$entryPoint' was not found in the plugin directory."
            }
        }
    }

    $artifact = $Request.Artifact
    $artifactPath = if ($artifact.PSObject.Properties.Name -contains 'Path') { [string]$artifact.Path } else { $null }
    if ([string]::IsNullOrWhiteSpace($artifactPath) -or -not [System.IO.Path]::IsPathFullyQualified($artifactPath) -or -not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Invocation = $null
            Error = [pscustomobject]@{
                Code = 'InstallerInvocationArtifactPathInvalid'
                Message = 'Installer invocation requires an absolute path to the completed artifact.'
            }
        }
    }

    $installer = if ($Request.PSObject.Properties.Name -contains 'Installer') { $Request.Installer } else { $null }
    $settings = if ($null -ne $installer -and $installer.PSObject.Properties.Name -contains 'settings') { $installer.settings } else { $null }
    if ($null -eq $settings -or ($settings -isnot [System.Collections.IDictionary] -and $settings -isnot [pscustomobject])) {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Invocation = $null
            Error = [pscustomobject]@{
                Code = 'InstallerInvocationSettingsInvalid'
                Message = 'Installer invocation requires structured installer settings.'
            }
        }
    }

    [pscustomobject][ordered]@{
        IsValid = $true
        Invocation = [pscustomobject][ordered]@{
            OperationId = $Request.OperationId
            DownloadOperationId = $Request.DownloadOperationId
            PluginId = $plugin.PluginId
            PluginModulePath = $resolvedEntryPoint
            ArtifactPath = [System.IO.Path]::GetFullPath($artifactPath)
            ArtifactFormat = $Selection.ArtifactFormat
            Settings = $settings
        }
        Error = $null
    }
}
