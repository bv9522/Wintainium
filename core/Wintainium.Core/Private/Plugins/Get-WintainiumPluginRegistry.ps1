function Get-WintainiumPluginRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PluginRoot
    )

    $plugins = [System.Collections.Generic.List[object]]::new()
    $descriptorErrors = [System.Collections.Generic.List[object]]::new()

    if (-not (Test-Path -LiteralPath $PluginRoot -PathType Container)) {
        return [pscustomobject]@{
            Plugins = @()
            DescriptorErrors = @([pscustomobject]@{ Code = 'PluginRootNotFound'; Message = "Plugin root '$PluginRoot' was not found." })
        }
    }

    foreach ($descriptorFile in @(Get-ChildItem -LiteralPath $PluginRoot -Filter 'plugin.json' -File -Recurse | Sort-Object FullName)) {
        $result = Test-WintainiumPluginDescriptor -DescriptorPath $descriptorFile.FullName
        if ($result.IsValid) {
            $plugins.Add([pscustomobject][ordered]@{
                    PluginId = $result.Descriptor.pluginId
                    PluginType = $result.Descriptor.pluginType
                    ContractVersions = @($result.Descriptor.contractVersions)
                    EntryPoint = if ($result.Descriptor.ContainsKey('entryPoint')) { $result.Descriptor.entryPoint } else { $null }
                    Capabilities = $result.Descriptor.capabilities
                    DescriptorPath = $result.DescriptorPath
                })
        }
        else {
            $descriptorErrors.Add($result)
        }
    }

    [pscustomobject][ordered]@{
        Plugins = $plugins.ToArray()
        DescriptorErrors = $descriptorErrors.ToArray()
    }
}
