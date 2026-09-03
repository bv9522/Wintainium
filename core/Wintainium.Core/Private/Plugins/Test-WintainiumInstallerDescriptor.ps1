function Test-WintainiumInstallerDescriptor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Descriptor
    )

    $errors = [System.Collections.Generic.List[object]]::new()

    if (-not $Descriptor.ContainsKey('pluginId') -or
        $Descriptor.pluginId -notmatch '^Wintainium\.installer\.[a-z0-9-]+(?:\.[a-z0-9-]+)*$') {
        $errors.Add([pscustomobject]@{
                Code = 'DescriptorInstallerPluginIdInvalid'
                Message = 'Installer descriptors require a valid Wintainium.installer.* pluginId.'
            })
    }

    if (-not $Descriptor.ContainsKey('pluginType') -or $Descriptor.pluginType -ne 'Installer') {
        $errors.Add([pscustomobject]@{
                Code = 'DescriptorInstallerPluginTypeInvalid'
                Message = 'Installer descriptors require pluginType=Installer.'
            })
    }

    if (-not $Descriptor.ContainsKey('contractVersions') -or
        @($Descriptor.contractVersions).Count -eq 0 -or
        @($Descriptor.contractVersions | Where-Object { $_ -isnot [string] -or $_ -notmatch '^[1-9][0-9]*$' }).Count -gt 0) {
        $errors.Add([pscustomobject]@{
                Code = 'DescriptorInstallerContractVersionsInvalid'
                Message = 'Installer descriptors require one or more positive major contract versions.'
            })
    }

    if (-not $Descriptor.ContainsKey('capabilities') -or
        $Descriptor.capabilities -isnot [System.Collections.IDictionary]) {
        $errors.Add([pscustomobject]@{
                Code = 'DescriptorInstallerCapabilitiesInvalid'
                Message = 'Installer descriptor capabilities must be an object.'
            })
    }
    else {
        $rawFormats = $Descriptor.capabilities['supportedFormats']

        if (-not $Descriptor.capabilities.ContainsKey('supportedFormats') -or $null -eq $rawFormats) {
            $errors.Add([pscustomobject]@{
                    Code = 'DescriptorInstallerFormatsMissing'
                    Message = 'Installer descriptors require a non-empty capabilities.supportedFormats array.'
                })
        }
        elseif ($rawFormats -is [string] -or $rawFormats -is [System.Collections.IDictionary]) {
            $errors.Add([pscustomobject]@{
                    Code = 'DescriptorInstallerFormatsInvalid'
                    Message = 'Installer supportedFormats must be an array of format identifier strings.'
                })
        }
        else {
            $formats = @($rawFormats)
            if ($formats.Count -eq 0) {
                $errors.Add([pscustomobject]@{
                        Code = 'DescriptorInstallerFormatsMissing'
                        Message = 'Installer descriptors require a non-empty capabilities.supportedFormats array.'
                    })
            }
            else {
                $invalidFormats = @($formats | Where-Object {
                        $_ -isnot [string] -or
                        $_.Trim().Length -eq 0 -or
                        $_ -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._+-]*$'
                    })

                if ($invalidFormats.Count -gt 0) {
                    $errors.Add([pscustomobject]@{
                            Code = 'DescriptorInstallerFormatsInvalid'
                            Message = 'Installer supportedFormats must contain non-empty format identifiers using letters, numbers, dot, underscore, plus, or hyphen.'
                        })
                }

                $normalizedFormats = @($formats | ForEach-Object { $_.ToString().Trim().ToLowerInvariant() })
                if ($normalizedFormats.Count -ne (@($normalizedFormats | Select-Object -Unique).Count)) {
                    $errors.Add([pscustomobject]@{
                            Code = 'DescriptorInstallerFormatsDuplicate'
                            Message = 'Installer supportedFormats must not contain duplicate identifiers.'
                        })
                }
            }
        }
    }

    [pscustomobject][ordered]@{
        IsValid = $errors.Count -eq 0
        Errors = $errors.ToArray()
    }
}
