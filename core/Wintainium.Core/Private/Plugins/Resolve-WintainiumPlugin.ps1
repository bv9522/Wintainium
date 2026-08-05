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
        [string]$RequiredContractVersion
    )

    $plugin = @($Plugins | Where-Object {
            $_.PluginId -eq $PluginId -and $_.PluginType -eq $PluginType -and $_.ContractVersions -contains $RequiredContractVersion
        }) | Select-Object -First 1

    if ($null -eq $plugin) {
        return [pscustomobject]@{
            IsResolved = $false
            Plugin = $null
            Error = [pscustomobject]@{
                Code = 'PluginNotResolved'
                Message = "No compatible $PluginType plugin was registered for '$PluginId' and contract '$RequiredContractVersion'."
            }
        }
    }

    [pscustomobject]@{
        IsResolved = $true
        Plugin = $plugin
        Error = $null
    }
}

