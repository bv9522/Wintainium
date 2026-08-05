function Test-WintainiumApplicationDefinition {
    <#
    .SYNOPSIS
    Validates an offline Wintainium application manifest and resolves its required plugins.

    .DESCRIPTION
    This Phase 1 command performs no network, download, installation, or state-management work.
    It returns structured validation data so future interfaces can present the same engine result.
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

        $installerResolution = Resolve-WintainiumPlugin -Plugins $registry.Plugins -PluginId $manifest.installer.pluginId -PluginType 'Installer' -RequiredContractVersion $manifest.installer.requiredContractVersion
        if ($installerResolution.IsResolved) {
            $installer = $installerResolution.Plugin
            $compatibility = Test-WintainiumInstallerCompatibility -Manifest $manifest -InstallerPlugin $installer
            if (-not $compatibility.IsCompatible) {
                $errors.Add($compatibility.Error)
            }
        }
        else {
            $errors.Add($installerResolution.Error)
        }
    }

    $severity = if ($errors.Count -eq 0) { 'Information' } else { 'Error' }
    $eventName = if ($errors.Count -eq 0) { 'ValidationSucceeded' } else { 'ValidationFailed' }
    $message = if ($errors.Count -eq 0) { 'Application definition is valid.' } else { 'Application definition is invalid.' }
    $logEvents.Add((New-WintainiumLogEvent -Severity $severity -OperationId $operationId -Component 'Core' -EventName $eventName -Message $message -Context @{ ErrorCount = $errors.Count; WarningCount = $warnings.Count }))

    [pscustomobject][ordered]@{
        OperationId = $operationId
        IsValid = $errors.Count -eq 0
        Manifest = $manifest
        ProviderPlugin = $provider
        InstallerPlugin = $installer
        Errors = $errors.ToArray()
        Warnings = $warnings.ToArray()
        LogEvents = $logEvents.ToArray()
    }
}

