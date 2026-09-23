function Get-WintainiumDefaultApplicationPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNull()][object]$PluginRegistry
    )

    $errors = [System.Collections.Generic.List[object]]::new()
    $plugins = @($PluginRegistry.Plugins)

    $installers = @($plugins | Where-Object {
        $_.PluginType -eq 'Installer' -and
        $_.Capabilities -is [System.Collections.IDictionary] -and
        @($_.Capabilities.supportedFormats).Count -gt 0 -and
        @($_.ContractVersions) -contains '1'
    } | Sort-Object DescriptorPath)

    if ($installers.Count -eq 0) {
        $errors.Add([pscustomobject][ordered]@{
            Code='ApplicationPolicyUnavailable'
            Path='$.Policy.Installer'
            Message='No registered installer plugin supports application onboarding under Core contract version 1.'
        })
    }
    elseif ($installers.Count -gt 1) {
        $errors.Add([pscustomobject][ordered]@{
            Code='ApplicationPolicyAmbiguous'
            Path='$.Policy.Installer'
            Message='Multiple registered installer plugins are eligible for the Core onboarding default policy.'
        })
    }

    $reconcilers = @($plugins | Where-Object {
        $_.PluginType -eq 'Reconciliation' -and
        $_.Capabilities -is [System.Collections.IDictionary] -and
        [bool]$_.Capabilities.applicationState -eq $true -and
        @($_.ContractVersions) -contains '1'
    } | Sort-Object DescriptorPath)

    if ($reconcilers.Count -eq 0) {
        $errors.Add([pscustomobject][ordered]@{
            Code='ApplicationPolicyUnavailable'
            Path='$.Policy.Reconciliation'
            Message='No registered reconciliation plugin supports application-state reconciliation under Core contract version 1.'
        })
    }
    elseif ($reconcilers.Count -gt 1) {
        $errors.Add([pscustomobject][ordered]@{
            Code='ApplicationPolicyAmbiguous'
            Path='$.Policy.Reconciliation'
            Message='Multiple registered reconciliation plugins are eligible for the Core onboarding default policy.'
        })
    }

    if ($errors.Count -gt 0) {
        return [pscustomobject][ordered]@{
            IsSuccessful=$false
            Status=if (@($errors | Where-Object Code -eq 'ApplicationPolicyAmbiguous').Count -gt 0) {'ApplicationPolicyAmbiguous'} else {'ApplicationPolicyUnavailable'}
            Policy=$null
            Errors=$errors.ToArray()
        }
    }

    $installer = $installers[0]
    $supportedFormats = @($installer.Capabilities.supportedFormats | ForEach-Object { [string]$_ } | Where-Object { $_ -in @('zip','msi','exe') } | Select-Object -Unique)
    if ($supportedFormats.Count -eq 0) {
        return [pscustomobject][ordered]@{
            IsSuccessful=$false
            Status='ApplicationPolicyUnavailable'
            Policy=$null
            Errors=@([pscustomobject][ordered]@{
                Code='ApplicationPolicyUnavailable'
                Path='$.Policy.Artifact.Formats'
                Message='The selected installer does not advertise a supported application artifact format.'
            })
        }
    }

    [pscustomobject][ordered]@{
        IsSuccessful=$true
        Status='Resolved'
        Policy=[pscustomobject][ordered]@{
            Installer=[pscustomobject][ordered]@{
                PluginId=[string]$installer.PluginId
                RequiredContractVersion='1'
                Settings=@{}
            }
            Reconciliation=[pscustomobject][ordered]@{
                PluginId=[string]$reconcilers[0].PluginId
                RequiredContractVersion='1'
                Settings=@{}
            }
            Release=[pscustomobject][ordered]@{ Channel='stable' }
            Artifact=[pscustomobject][ordered]@{
                Formats=$supportedFormats
                Architectures=@('x64','x86','arm64','neutral')
                AllowUnknownArchitecture=$false
            }
        }
        Errors=@()
    }
}
