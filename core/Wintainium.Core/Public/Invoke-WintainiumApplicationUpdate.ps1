<#
.SYNOPSIS
Invokes a complete application update lifecycle.

.DESCRIPTION
Executes the Core application update lifecycle for one application manifest.
The command is the public execution boundary over Wintainium internal
orchestration lifecycle. It accepts the application inputs required to
validate, discover, decide, download, verify, install, reconcile, and persist
installed state.

Operation identity is created by Core and is returned by the lifecycle result;
the caller does not supply an OperationId. Internal orchestration objects and
dependency-injection parameters are not part of this public command contract.

This command performs update execution. Use Test-WintainiumApplicationDefinition
for validation-only work and Get-WintainiumApplicationRelease for
validation-and-release-discovery work.

.PARAMETER ManifestPath
Absolute path to the application manifest.

.PARAMETER StateRoot
Root directory used for authoritative installed-application state.

.PARAMETER MachineArchitecture
Architecture of the machine on which the application update will execute.

.PARAMETER DownloadRoot
Absolute root directory used for downloaded update artifacts.

.PARAMETER PluginRoot
Root directory containing Wintainium plugins.

.PARAMETER SchemaPath
Path to the application manifest JSON schema.

.PARAMETER InstallerTimeoutMilliseconds
Maximum installer execution time in milliseconds. The default is 600000.

.PARAMETER CancellationToken
Optional cancellation token propagated through the update lifecycle.

.OUTPUTS
PSCustomObject. The command returns a stable, presentation-neutral public result projection with OperationId, IsSuccessful, WasCancelled, Status, ApplicationId, Stages, Errors, Warnings, LogEvents, and Error properties.
Internal orchestration state and stage-operation objects are not exposed.

.EXAMPLE
Invoke-WintainiumApplicationUpdate -ManifestPath 'C:\Wintainium\manifests\example.wintainium.json' -StateRoot 'C:\Wintainium\State' -MachineArchitecture 'x64' -DownloadRoot 'C:\Wintainium\Downloads'

Executes the application update lifecycle using the default plugin and schema
locations and the default installer timeout.

.EXAMPLE
Invoke-WintainiumApplicationUpdate -ManifestPath 'C:\Wintainium\manifests\example.wintainium.json' -StateRoot 'C:\Wintainium\State' -MachineArchitecture 'x64' -DownloadRoot 'C:\Wintainium\Downloads' -InstallerTimeoutMilliseconds 120000 -CancellationToken $cancellationToken

Executes the lifecycle with an explicit installer timeout and cancellation
token.
#>
function Invoke-WintainiumApplicationUpdate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$ManifestPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$StateRoot,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$MachineArchitecture,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$DownloadRoot,
        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),
        [ValidateRange(1, 2147483647)] [int]$InstallerTimeoutMilliseconds = 600000,
        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
    )

    $lifecycleResult = Invoke-WintainiumApplicationUpdateLifecycle @PSBoundParameters
    ConvertTo-WintainiumPublicApplicationUpdateResult -LifecycleResult $lifecycleResult
}
