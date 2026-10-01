<#
.SYNOPSIS
Validates an application manifest and discovers releases declared by its provider.

.DESCRIPTION
Validates the application manifest and performs provider release discovery.
This command does not decide whether an update is available, download an
artifact, or install anything.

.PARAMETER ManifestPath
Path to the application manifest.

.PARAMETER PluginRoot
Root directory containing Wintainium plugins.

.PARAMETER SchemaPath
Path to the application manifest JSON schema.

.PARAMETER OperationId
Optional lifecycle correlation identifier. When supplied, it is preserved.

.OUTPUTS
PSCustomObject. The result contains OperationId, IsSuccessful, Status,
Manifest, ProviderPlugin, Releases, Errors, Warnings, and LogEvents.

.EXAMPLE
Get-WintainiumApplicationRelease -ManifestPath 'C:\Wintainium\manifests\example.wintainium.json'

Validates the manifest and asks its declared provider to discover releases.
#>
function Get-WintainiumApplicationRelease {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$ManifestPath,
        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),
        [string]$OperationId
    )

    $validation = Test-WintainiumApplicationDefinition -ManifestPath $ManifestPath -PluginRoot $PluginRoot -SchemaPath $SchemaPath -OperationId $OperationId
    $operationId=$validation.OperationId
    $errors=[System.Collections.Generic.List[object]]::new(); $warnings=[System.Collections.Generic.List[object]]::new(); $logEvents=[System.Collections.Generic.List[object]]::new(); $releases=[System.Collections.Generic.List[object]]::new()
    foreach($item in @($validation.Errors)){$errors.Add($item)}; foreach($item in @($validation.Warnings)){$warnings.Add($item)}; foreach($item in @($validation.LogEvents)){$logEvents.Add($item)}
    if(-not $validation.IsValid){return [pscustomobject][ordered]@{OperationId=$operationId;IsSuccessful=$false;Status='ApplicationDefinitionInvalid';Manifest=$validation.Manifest;ProviderPlugin=$validation.ProviderPlugin;Releases=$releases.ToArray();Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray()}}
    $manifest=$validation.Manifest; $provider=$validation.ProviderPlugin

    # Release discovery is capability-driven. A valid provider may resolve and
    # identify an application without implementing release discovery. In that
    # case, return a successful structured result with a warning rather than
    # invoking a missing provider operation and converting a valid application
    # into a collection failure.
    $supportsReleaseDiscovery = $provider.Capabilities -is [System.Collections.IDictionary] -and
        $provider.Capabilities.ContainsKey('releaseDiscovery') -and
        $provider.Capabilities.releaseDiscovery -eq $true
    if (-not $supportsReleaseDiscovery) {
        $warning=[pscustomobject][ordered]@{
            Code='ReleaseDiscoveryUnsupported'
            Message="Provider '$($provider.PluginId)' does not advertise release discovery capability for this application."
        }
        return [pscustomobject][ordered]@{
            OperationId=$operationId
            IsSuccessful=$true
            Status='ReleaseDiscoveryUnsupported'
            Manifest=$manifest
            ProviderPlugin=$provider
            Releases=@()
            Errors=@()
            Warnings=@($warning)
            LogEvents=@()
        }
    }

    $request=[pscustomobject][ordered]@{OperationId=$operationId;ApplicationId=[string]$manifest.Id;ProviderId=[string]$provider.PluginId;RequiredContractVersion=[string]$manifest.Source.requiredContractVersion;Settings=if($manifest.Source.settings -is [System.Collections.IDictionary]){$manifest.Source.settings}else{@{}};DiscoveryContext=[pscustomobject][ordered]@{ReleaseChannel=[string]$manifest.Release.channel;ArtifactFormats=@($manifest.Artifact.formats);Architectures=@($manifest.Artifact.architectures);AllowUnknownArchitecture=[bool]$manifest.Artifact.allowUnknownArchitecture}}
    $providerResult=Invoke-WintainiumProviderOperation -Provider $provider -Request $request
    foreach($item in @($providerResult.Releases)){$releases.Add($item)}; foreach($item in @($providerResult.Errors)){$errors.Add($item)}; foreach($item in @($providerResult.Warnings)){$warnings.Add($item)}; foreach($item in @($providerResult.LogEvents)){$logEvents.Add($item)}
    [pscustomobject][ordered]@{OperationId=$operationId;IsSuccessful=[bool]$providerResult.IsSuccessful -and $errors.Count -eq 0;Status=[string]$providerResult.Status;Manifest=$manifest;ProviderPlugin=$provider;Releases=$releases.ToArray();Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray()}
}
