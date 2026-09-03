function Test-WintainiumPluginDescriptor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DescriptorPath
    )

    $errors = [System.Collections.Generic.List[object]]::new()
    $descriptor = $null

    try {
        $json = Get-Content -LiteralPath $DescriptorPath -Raw -Encoding utf8 -ErrorAction Stop
        $descriptor = ConvertFrom-Json -InputObject $json -AsHashtable -Depth 100 -ErrorAction Stop
    }
    catch {
        $errors.Add([pscustomobject]@{ Code = 'DescriptorJsonInvalid'; Message = $_.Exception.Message })
    }

    if ($null -ne $descriptor) {
        if (-not $descriptor.ContainsKey('pluginId') -or $descriptor.pluginId -notmatch '^Wintainium\.(provider|installer)\.[a-z0-9-]+(?:\.[a-z0-9-]+)*$') {
            $errors.Add([pscustomobject]@{ Code = 'DescriptorPluginIdInvalid'; Message = 'pluginId is missing or invalid.' })
        }

        if (-not $descriptor.ContainsKey('pluginType') -or $descriptor.pluginType -notin @('Provider', 'Installer')) {
            $errors.Add([pscustomobject]@{ Code = 'DescriptorPluginTypeInvalid'; Message = 'pluginType must be Provider or Installer.' })
        }

        if (-not $descriptor.ContainsKey('contractVersions') -or $descriptor.contractVersions.Count -eq 0 -or @($descriptor.contractVersions | Where-Object { $_ -notmatch '^[1-9][0-9]*$' }).Count -gt 0) {
            $errors.Add([pscustomobject]@{ Code = 'DescriptorContractVersionsInvalid'; Message = 'contractVersions must contain one or more positive major versions.' })
        }

        if (-not $descriptor.ContainsKey('capabilities') -or $descriptor.capabilities -isnot [System.Collections.IDictionary]) {
            $errors.Add([pscustomobject]@{ Code = 'DescriptorCapabilitiesInvalid'; Message = 'capabilities must be an object.' })
        }

        $pluginType = if ($descriptor.ContainsKey('pluginType')) { [string]$descriptor.pluginType } else { $null }
        $capabilities = if ($descriptor.ContainsKey('capabilities') -and $descriptor.capabilities -is [System.Collections.IDictionary]) { $descriptor.capabilities } else { $null }

        if ($pluginType -eq 'Provider') {
            if (-not $descriptor.ContainsKey('entryPoint') -or
                $descriptor.entryPoint -isnot [string] -or
                $descriptor.entryPoint -notmatch '^[^\\/:*?"<>|]+\.psm1$' -or
                $descriptor.entryPoint -match '(^|[\\/])\.\.([\\/]|$)') {
                $errors.Add([pscustomobject]@{ Code = 'DescriptorProviderEntryPointInvalid'; Message = 'Provider descriptors require a relative .psm1 entryPoint without parent-directory traversal.' })
            }

            if ($null -ne $capabilities) {
                if (-not $capabilities.ContainsKey('releaseDiscovery') -or $capabilities.releaseDiscovery -ne $true) {
                    $errors.Add([pscustomobject]@{ Code = 'DescriptorProviderReleaseDiscoveryMissing'; Message = 'Provider descriptors require capabilities.releaseDiscovery=true.' })
                }

                if (-not $capabilities.ContainsKey('artifactDiscovery') -or $capabilities.artifactDiscovery -ne $true) {
                    $errors.Add([pscustomobject]@{ Code = 'DescriptorProviderArtifactDiscoveryMissing'; Message = 'Provider descriptors require capabilities.artifactDiscovery=true.' })
                }
            }
        }

        if ($pluginType -eq 'Installer' -and $null -ne $capabilities) {
            $installerResult = Test-WintainiumInstallerDescriptor -Descriptor $descriptor
            foreach ($installerError in @($installerResult.Errors)) {
                $errors.Add($installerError)
            }
        }
    }

    [pscustomobject][ordered]@{
        DescriptorPath = $DescriptorPath
        Descriptor = $descriptor
        IsValid = $errors.Count -eq 0
        Errors = $errors.ToArray()
    }
}
