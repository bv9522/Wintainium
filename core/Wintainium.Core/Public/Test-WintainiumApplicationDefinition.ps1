function Test-WintainiumApplicationDefinition {
    <#
    .SYNOPSIS
    Validates an offline Wintainium application manifest and resolves its required plugins.

    .DESCRIPTION
    Performs no network, download, installation, or state-management work. The command
    validates the manifest and resolves the provider and installer plugins required by
    that application definition. It returns structured validation data for CLI, automation,
    and future graphical clients.

    .PARAMETER ManifestPath
    Path to the application manifest to validate.

    .PARAMETER PluginRoot
    Root directory containing installed Wintainium plugins.

    .PARAMETER SchemaPath
    Path to the application-manifest JSON schema used for validation.

    .OUTPUTS
    PSCustomObject. The result contains OperationId, IsValid, Manifest, ProviderPlugin,
    InstallerPlugin, InstallerPlugins, InstallerPluginCandidates, Errors, Warnings, and LogEvents.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,

        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json')
    )

    $operationId = [guid]::NewGuid().Guid
    $errors = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $logEvents = [System.Collections.Generic.List[object]]::new()
    $installerPlugins = [System.Collections.Generic.List[object]]::new()
    $installerPluginCandidates = [System.Collections.Generic.List[object]]::new()
    $manifest = $null
    $provider = $null
    $installer = $null

    $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $operationId -Component 'Core' -EventName 'ValidationStarted' -Message 'Application definition validation started.' -Context @{ ManifestPath = $ManifestPath }))

    try {
        $manifestLoad = Import-WintainiumManifest -Path $ManifestPath -SchemaPath $SchemaPath
        $manifest = $manifestLoad.Manifest
        foreach ($errorRecord in @($manifestLoad.Errors)) {
            $errors.Add($errorRecord)
        }
    }
    catch {
        $errors.Add([pscustomobject][ordered]@{
                Code = 'ManifestValidationFailed'
                Path = '$'
                Message = $_.Exception.Message
            })
    }

    if ($errors.Count -eq 0) {
        $registry = Get-WintainiumPluginRegistry -PluginRoot $PluginRoot
        foreach ($descriptorError in @($registry.DescriptorErrors)) {
            $warnings.Add([pscustomobject]@{ Code = 'PluginDescriptorIgnored'; Message = 'An invalid plugin descriptor was ignored by the registry.'; Detail = $descriptorError })
        }

        $providerResolution = Resolve-WintainiumPlugin -Plugins $registry.Plugins -PluginId $manifest.source.pluginId -PluginType 'Provider' -RequiredContractVersion $manifest.source.requiredContractVersion
        if ($providerResolution.IsResolved) {
            $provider = $providerResolution.Plugin
        }
        else {
            $errors.Add($providerResolution.Error)
        }

        $installerCandidates = [System.Collections.Generic.List[object]]::new()
        if ($null -ne $manifest.installer) {
            $installerCandidates.Add([pscustomobject][ordered]@{
                    PluginId = [string]$manifest.installer.pluginId
                    RequiredContractVersion = [string]$manifest.installer.requiredContractVersion
                    IsFallback = $false
                    Order = 0
                    Declaration = $manifest.installer
                })

            $fallbackOrder = 1
            foreach ($fallback in @($manifest.installer.fallbacks)) {
                if ($null -ne $fallback) {
                    $installerCandidates.Add([pscustomobject][ordered]@{
                            PluginId = [string]$fallback.pluginId
                            RequiredContractVersion = [string]$fallback.requiredContractVersion
                            IsFallback = $true
                            Order = $fallbackOrder
                            Declaration = $fallback
                        })
                    $fallbackOrder++
                }
            }
        }

        foreach ($candidate in $installerCandidates) {
            $resolution = Resolve-WintainiumPlugin `
                -Plugins $registry.Plugins `
                -PluginId $candidate.PluginId `
                -PluginType 'Installer' `
                -RequiredContractVersion $candidate.RequiredContractVersion

            if ($resolution.IsResolved) {
                $installerPlugin = $resolution.Plugin
                $installerPlugins.Add($installerPlugin)

                if (-not $candidate.IsFallback) {
                    $installer = $installerPlugin
                }

                $installerPluginCandidates.Add([pscustomobject][ordered]@{
                        PluginId = $candidate.PluginId
                        RequiredContractVersion = $candidate.RequiredContractVersion
                        IsFallback = $candidate.IsFallback
                        Order = $candidate.Order
                        IsResolved = $true
                        Plugin = $installerPlugin
                        Error = $null
                    })
            }
            else {
                $installerPluginCandidates.Add([pscustomobject][ordered]@{
                        PluginId = $candidate.PluginId
                        RequiredContractVersion = $candidate.RequiredContractVersion
                        IsFallback = $candidate.IsFallback
                        Order = $candidate.Order
                        IsResolved = $false
                        Plugin = $null
                        Error = $resolution.Error
                    })

                if ($candidate.IsFallback) {
                    $warnings.Add([pscustomobject]@{
                            Code = 'InstallerFallbackNotResolved'
                            Message = "Declared installer fallback '$($candidate.PluginId)' could not be resolved."
                            Detail = $resolution.Error
                        })
                }
                else {
                    $errors.Add($resolution.Error)
                }
            }
        }

        $compatibleInstallerFound = $false
        foreach ($resolvedInstaller in @($installerPlugins)) {
            $compatibility = Test-WintainiumInstallerCompatibility -Manifest $manifest -InstallerPlugin $resolvedInstaller
            if ($compatibility.IsCompatible) {
                $compatibleInstallerFound = $true
                break
            }
        }

        if (-not $compatibleInstallerFound -and $installerPlugins.Count -gt 0) {
            $primaryCompatibility = Test-WintainiumInstallerCompatibility -Manifest $manifest -InstallerPlugin $installerPlugins[0]
            $errors.Add($primaryCompatibility.Error)
        }
        elseif (-not $compatibleInstallerFound -and $installerCandidates.Count -gt 0 -and $errors.Count -eq 0) {
            $errors.Add([pscustomobject]@{
                    Code = 'InstallerArtifactIncompatible'
                    Message = "No resolved installer candidate supports any of the manifest's declared artifact formats."
                })
        }
    }

    $severity = if ($errors.Count -eq 0) { 'Information' } else { 'Error' }
    $eventName = if ($errors.Count -eq 0) { 'ValidationSucceeded' } else { 'ValidationFailed' }
    $message = if ($errors.Count -eq 0) { 'Application definition is valid.' } else { 'Application definition is invalid.' }
    $logEvents.Add((New-WintainiumLogEvent -Severity $severity -OperationId $operationId -Component 'Core' -EventName $eventName -Message $message -Context @{ ErrorCount = $errors.Count; WarningCount = $warnings.Count; InstallerCandidateCount = $installerPluginCandidates.Count; ResolvedInstallerCount = $installerPlugins.Count }))

    [pscustomobject][ordered]@{
        OperationId = $operationId
        IsValid = $errors.Count -eq 0
        Manifest = $manifest
        ProviderPlugin = $provider
        InstallerPlugin = $installer
        InstallerPlugins = $installerPlugins.ToArray()
        InstallerPluginCandidates = $installerPluginCandidates.ToArray()
        Errors = $errors.ToArray()
        Warnings = $warnings.ToArray()
        LogEvents = $logEvents.ToArray()
    }
}
