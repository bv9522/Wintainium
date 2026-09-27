function Set-WintainiumApplicationReconciliationSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Settings,

        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,

        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),

        [string]$OperationId
    )

    $resolvedOperationId = [guid]::Empty
    if ([string]::IsNullOrWhiteSpace($OperationId)) {
        $resolvedOperationId = [guid]::NewGuid()
    }
    elseif (-not [guid]::TryParse($OperationId, [ref]$resolvedOperationId)) {
        return [pscustomobject][ordered]@{
            OperationId=$OperationId
            IsSuccessful=$false
            Status='InvalidSettings'
            ManifestPath=$ManifestPath
            Manifest=$null
            Errors=@([pscustomobject][ordered]@{
                Code='OperationIdInvalid'
                Path='$.OperationId'
                Message='OperationId must be a valid GUID.'
            })
            Warnings=@()
            LogEvents=@()
        }
    }
    $resolvedOperationId=$resolvedOperationId.ToString()

    $errors=[System.Collections.Generic.List[object]]::new()
    $warnings=[System.Collections.Generic.List[object]]::new()
    $logEvents=[System.Collections.Generic.List[object]]::new()

    if ($Settings -is [string] -or $Settings -is [System.Collections.IDictionary] -or
        $Settings.PSObject.Properties.Count -eq 0) {
        if ($Settings -is [string]) {
            $errors.Add([pscustomobject][ordered]@{
                Code='ReconciliationSettingsInvalid'
                Path='$.Reconciliation.Settings'
                Message='Reconciliation settings must be a structured object, not a scalar string.'
            })
        }
    }

    $import = Import-WintainiumManifest -Path $ManifestPath -SchemaPath $SchemaPath
    foreach ($errorRecord in @($import.Errors)) { $errors.Add($errorRecord) }

    if (-not $import.IsValid) {
        return [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId
            IsSuccessful=$false
            Status='ManifestInvalid'
            ManifestPath=$ManifestPath
            Manifest=$null
            Errors=$errors.ToArray()
            Warnings=$warnings.ToArray()
            LogEvents=$logEvents.ToArray()
        }
    }

    $manifest = $import.Manifest
    if (-not $manifest.PSObject.Properties['reconciliation'] -or $null -eq $manifest.reconciliation) {
        $errors.Add([pscustomobject][ordered]@{
            Code='ReconciliationConfigurationMissing'
            Path='$.Reconciliation'
            Message='The application manifest must declare a reconciliation plugin before its settings can be configured.'
        })
    }
    else {
        $pluginId = [string]$manifest.reconciliation.pluginId
        if ([string]::IsNullOrWhiteSpace($pluginId)) {
            $errors.Add([pscustomobject][ordered]@{
                Code='ReconciliationPluginMissing'
                Path='$.Reconciliation.PluginId'
                Message='The application manifest must declare a reconciliation plugin before its settings can be configured.'
            })
        }
        else {
            $registry = Get-WintainiumPluginRegistry -PluginRoot $PluginRoot
            foreach ($descriptorError in @($registry.DescriptorErrors)) {
                $warnings.Add([pscustomobject][ordered]@{
                    Code='PluginDescriptorIgnored'
                    Message='An invalid plugin descriptor was ignored by the registry.'
                    Detail=$descriptorError
                })
            }

            $matches=@($registry.Plugins | Where-Object { [string]$_.PluginId -ieq $pluginId })
            if ($matches.Count -eq 0) {
                $errors.Add([pscustomobject][ordered]@{
                    Code='ReconciliationPluginUnavailable'
                    Path='$.Reconciliation.PluginId'
                    Message="Reconciliation plugin '$pluginId' is not registered."
                })
            }
            elseif ($matches.Count -gt 1) {
                $errors.Add([pscustomobject][ordered]@{
                    Code='ReconciliationPluginAmbiguous'
                    Path='$.Reconciliation.PluginId'
                    Message="Multiple registered descriptors identify reconciliation plugin '$pluginId'."
                })
            }
            else {
                $plugin = $matches[0]
                if ($plugin.PluginType -ne 'Reconciliation') {
                    $errors.Add([pscustomobject][ordered]@{
                        Code='ReconciliationPluginTypeInvalid'
                        Path='$.Reconciliation.PluginId'
                        Message="Plugin '$pluginId' is not a reconciliation plugin."
                    })
                }
                if (@($plugin.ContractVersions) -notcontains [string]$manifest.reconciliation.requiredContractVersion) {
                    $errors.Add([pscustomobject][ordered]@{
                        Code='ReconciliationPluginContractUnsupported'
                        Path='$.Reconciliation.RequiredContractVersion'
                        Message="Plugin '$pluginId' does not advertise the manifest's required reconciliation contract version."
                    })
                }
                if (-not ($plugin.Capabilities -is [System.Collections.IDictionary]) -or
                    [bool]$plugin.Capabilities.applicationState -ne $true) {
                    $errors.Add([pscustomobject][ordered]@{
                        Code='ReconciliationPluginCapabilityUnavailable'
                        Path='$.Reconciliation.PluginId'
                        Message="Plugin '$pluginId' does not advertise application-state reconciliation capability."
                    })
                }
            }
        }
    }

    if ($errors.Count -gt 0) {
        return [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId
            IsSuccessful=$false
            Status='InvalidSettings'
            ManifestPath=$ManifestPath
            Manifest=$manifest
            Errors=$errors.ToArray()
            Warnings=$warnings.ToArray()
            LogEvents=$logEvents.ToArray()
        }
    }

    $updated = $manifest | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $updated.reconciliation.settings = $Settings

    try {
        $destination = Set-WintainiumApplicationDefinition -ApplicationDefinition $updated -ManifestRoot (Split-Path -Path $ManifestPath -Parent) -SchemaPath $SchemaPath
    }
    catch {
        $errors.Add([pscustomobject][ordered]@{
            Code='ReconciliationSettingsPersistenceFailed'
            Path='$.Reconciliation.Settings'
            Message=$_.Exception.Message
        })
        return [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId
            IsSuccessful=$false
            Status='PersistenceFailed'
            ManifestPath=$ManifestPath
            Manifest=$updated
            Errors=$errors.ToArray()
            Warnings=$warnings.ToArray()
            LogEvents=$logEvents.ToArray()
        }
    }

    $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $resolvedOperationId -Component 'Core' -EventName 'ReconciliationSettingsUpdated' -Message 'Application reconciliation settings were updated through the Core manifest boundary.' -Context @{ApplicationId=[string]$updated.id;ManifestPath=$destination;PluginId=[string]$updated.reconciliation.pluginId}))

    [pscustomobject][ordered]@{
        OperationId=$resolvedOperationId
        IsSuccessful=$true
        Status='Updated'
        ManifestPath=$destination
        Manifest=$updated
        Errors=@()
        Warnings=$warnings.ToArray()
        LogEvents=$logEvents.ToArray()
    }
}
