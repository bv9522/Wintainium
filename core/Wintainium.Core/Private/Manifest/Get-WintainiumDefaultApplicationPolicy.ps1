function Get-WintainiumDefaultApplicationPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNull()][object]$PluginRegistry,

        [string]$ApplicationName
    )

    $errors = [System.Collections.Generic.List[object]]::new()
    $plugins = @($PluginRegistry.Plugins)

    $installers = @($plugins | Where-Object {
        $_.PluginType -eq 'Installer' -and
        $_.Capabilities -is [System.Collections.IDictionary] -and
        @($_.Capabilities.supportedFormats).Count -gt 0 -and
        @($_.ContractVersions) -contains '1'
    })

    # Default onboarding policy is Core-owned and deterministic. Artifact
    # architecture/eligibility is evaluated later and outranks format choice.
    # The order below is only the default mechanism preference; an authored
    # manifest may explicitly choose another installer and format.
    $preferredFormats = @('exe','msi','msix','zip')

    $installerCandidates = @()
    foreach ($format in $preferredFormats) {
        $matches = @(
            foreach ($installer in @($installers | Sort-Object DescriptorPath)) {
                $supportedFormats = @($installer.Capabilities.supportedFormats | ForEach-Object {
                    if ($_ -is [string]) { $_.Trim().ToLowerInvariant() }
                })
                if ($supportedFormats -contains $format) {
                    [pscustomobject]@{
                        Installer = $installer
                        Format = $format
                    }
                }
            }
        )
        if ($matches.Count -gt 0) {
            $installerCandidates = $matches
            break
        }
    }

    if ($installers.Count -eq 0) {
        $errors.Add([pscustomobject][ordered]@{
            Code='ApplicationPolicyUnavailable'
            Path='$.Policy.Installer'
            Message='No registered installer plugin supports application onboarding under Core contract version 1.'
        })
    }
    elseif (@($installerCandidates).Count -eq 0) {
        $errors.Add([pscustomobject][ordered]@{
            Code='ApplicationPolicyUnavailable'
            Path='$.Policy.Installer'
            Message='No registered installer plugin advertises a supported default application artifact format.'
        })
    }
    elseif (@($installerCandidates).Count -gt 1) {
        $errors.Add([pscustomobject][ordered]@{
            Code='ApplicationPolicyAmbiguous'
            Path='$.Policy.Installer'
            Message="Multiple registered installer plugins support the default artifact format '$($installerCandidates[0].Format)'; Core will not silently choose between them."
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

    $installer = $installerCandidates[0].Installer
    $selectedFormat = $installerCandidates[0].Format
    $reconciler = $reconcilers[0]

    $reconciliationRequiresConfiguration = (
        $reconciler.Capabilities -is [System.Collections.IDictionary] -and
        $reconciler.Capabilities.Contains('requiresConfiguration') -and
        [bool]$reconciler.Capabilities['requiresConfiguration'] -eq $true
    )

    if ($reconciliationRequiresConfiguration) {
        if ([string]::IsNullOrWhiteSpace($ApplicationName)) {
            return [pscustomobject][ordered]@{
                IsSuccessful=$false
                Status='ApplicationPolicyConfigurationRequired'
                Policy=$null
                Errors=@([pscustomobject][ordered]@{
                    Code='ApplicationPolicyConfigurationRequired'
                    Path='$.Policy.Reconciliation.Settings'
                    Message="The selected reconciliation plugin '$($reconciler.PluginId)' requires application-specific settings and cannot be selected by the default onboarding policy without them."
                })
            }
        }

        # The application source has already established a normalized name. Make
        # the Windows reconciler's registry criterion explicit in the manifest,
        # rather than allowing the reconciler to infer it from manifest.name.
        $reconciliationSettings = [ordered]@{
            registry = [ordered]@{
                locations = @(
                    [ordered]@{ scope='machine'; view='64' }
                    [ordered]@{ scope='machine'; view='32' }
                    [ordered]@{ scope='user'; view='native' }
                )
                match = @(
                    [ordered]@{ value='DisplayName'; equals=[string]$ApplicationName }
                )
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
                    PluginId=[string]$reconciler.PluginId
                    RequiredContractVersion='1'
                    Settings=$reconciliationSettings
                }
                Release=[pscustomobject][ordered]@{ Channel='stable' }
                Artifact=[pscustomobject][ordered]@{
                    Formats=@($selectedFormat)
                    Architectures=@('x64','x86','arm64','neutral')
                    AllowUnknownArchitecture=$false
                }
            }
            Errors=@()
        }
        return
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
                PluginId=[string]$reconciler.PluginId
                RequiredContractVersion='1'
                Settings=@{}
            }
            Release=[pscustomobject][ordered]@{ Channel='stable' }
            Artifact=[pscustomobject][ordered]@{
                Formats=@($selectedFormat)
                Architectures=@('x64','x86','arm64','neutral')
                AllowUnknownArchitecture=$false
            }
        }
        Errors=@()
    }
}
