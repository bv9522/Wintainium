function Resolve-WintainiumPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Plugins,

        [Parameter(Mandatory)]
        [string]$PluginId,

        [Parameter(Mandatory)]
        [ValidateSet('Provider', 'Installer')]
        [string]$PluginType,

        [Parameter(Mandatory)]
        [string]$RequiredContractVersion,

        [string[]]$RequiredCapabilities = @()
    )

    $pluginsByIdentity = @($Plugins | Where-Object {
            $_.PluginId -eq $PluginId -and $_.PluginType -eq $PluginType
        })

    if ($pluginsByIdentity.Count -eq 0) {
        $errorCode = if ($PluginType -eq 'Provider') { 'ProviderNotRegistered' } else { 'PluginNotResolved' }
        return [pscustomobject]@{
            IsResolved = $false
            Plugin = $null
            Error = [pscustomobject]@{
                Code = $errorCode
                Message = "No $PluginType plugin was registered for '$PluginId'."
            }
        }
    }

    $compatiblePlugins = @($pluginsByIdentity | Where-Object {
            $_.ContractVersions -contains $RequiredContractVersion
        })

    if ($compatiblePlugins.Count -eq 0) {
        $errorCode = if ($PluginType -eq 'Provider') { 'ProviderContractIncompatible' } else { 'PluginNotResolved' }
        return [pscustomobject]@{
            IsResolved = $false
            Plugin = $null
            Error = [pscustomobject]@{
                Code = $errorCode
                Message = "No compatible $PluginType plugin was registered for '$PluginId' and contract '$RequiredContractVersion'."
            }
        }
    }

    $capabilityCompatiblePlugins = @($compatiblePlugins | Where-Object {
            $plugin = $_
            $capabilities = if ($plugin.Capabilities -is [System.Collections.IDictionary]) { $plugin.Capabilities } else { @{} }
            @($RequiredCapabilities | Where-Object { -not ($capabilities.ContainsKey($_) -and $capabilities[$_] -eq $true) }).Count -eq 0
        })

    if ($capabilityCompatiblePlugins.Count -eq 0) {
        $required = ($RequiredCapabilities -join ', ')
        return [pscustomobject]@{
            IsResolved = $false
            Plugin = $null
            Error = [pscustomobject]@{
                Code = if ($PluginType -eq 'Provider') { 'ProviderCapabilityUnsupported' } else { 'PluginNotResolved' }
                Message = "No compatible $PluginType plugin for '$PluginId' declares all required capabilities: $required."
            }
        }
    }

    $plugin = $capabilityCompatiblePlugins | Sort-Object DescriptorPath | Select-Object -First 1

    [pscustomobject]@{
        IsResolved = $true
        Plugin = $plugin
        Error = $null
    }
}

