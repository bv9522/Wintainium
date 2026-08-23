function Get-WintainiumApplicationRelease {
    <#
    .SYNOPSIS
    Validates an application manifest, resolves its provider, and discovers releases.

    .DESCRIPTION
    This command is the Phase 3 Core boundary between a validated application
    definition and provider-backed release discovery. Manifest validation and
    plugin resolution occur before the provider is invoked. The provider
    receives only a purpose-built discovery request and its normalized result
    is returned through the Core operation boundary.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,

        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json')
    )

    $validation = Test-WintainiumApplicationDefinition -ManifestPath $ManifestPath -PluginRoot $PluginRoot -SchemaPath $SchemaPath
    $operationId = $validation.OperationId
    $errors = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $logEvents = [System.Collections.Generic.List[object]]::new()

    foreach ($item in @($validation.Errors)) { $errors.Add($item) }
    foreach ($item in @($validation.Warnings)) { $warnings.Add($item) }
    foreach ($item in @($validation.LogEvents)) { $logEvents.Add($item) }

    if (-not $validation.IsValid) {
        return [pscustomobject][ordered]@{
            OperationId = $operationId
            IsSuccessful = $false
            Status = 'ApplicationDefinitionInvalid'
            Manifest = $validation.Manifest
            ProviderPlugin = $validation.ProviderPlugin
            Releases = @()
            Errors = $errors.ToArray()
            Warnings = $warnings.ToArray()
            LogEvents = $logEvents.ToArray()
        }
    }

    $manifest = $validation.Manifest
    $provider = $validation.ProviderPlugin
    $request = [pscustomobject][ordered]@{
        OperationId = $operationId
        ApplicationId = [string]$manifest.Id
        ProviderId = [string]$provider.PluginId
        RequiredContractVersion = [string]$manifest.Source.requiredContractVersion
        Settings = if ($manifest.Source.settings -is [System.Collections.IDictionary]) { $manifest.Source.settings } else { @{} }
        DiscoveryContext = [pscustomobject][ordered]@{
            ReleaseChannel = [string]$manifest.Release.channel
            ArtifactFormats = @($manifest.Artifact.formats)
            Architectures = @($manifest.Artifact.architectures)
            AllowUnknownArchitecture = [bool]$manifest.Artifact.allowUnknownArchitecture
        }
    }

    $providerResult = Invoke-WintainiumProviderOperation -Provider $provider -Request $request

    foreach ($item in @($providerResult.Errors)) { $errors.Add($item) }
    foreach ($item in @($providerResult.Warnings)) { $warnings.Add($item) }
    foreach ($item in @($providerResult.LogEvents)) { $logEvents.Add($item) }

    [pscustomobject][ordered]@{
        OperationId = $operationId
        IsSuccessful = [bool]$providerResult.IsSuccessful -and $errors.Count -eq 0
        Status = [string]$providerResult.Status
        Manifest = $manifest
        ProviderPlugin = $provider
        Releases = @($providerResult.Releases)
        Errors = $errors.ToArray()
        Warnings = $warnings.ToArray()
        LogEvents = $logEvents.ToArray()
    }
}
