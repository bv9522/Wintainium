<#
.SYNOPSIS
Invokes a complete first-install lifecycle for one application manifest.

.DESCRIPTION
Executes the Core application installation lifecycle for an application that is
not currently installed. The operation reuses the shared lifecycle engine used
by application updates: manifest validation, release discovery, installation
decision, download, verification, installer selection, installation, and
authoritative reconciliation.

This command is a Core execution boundary. It does not contain desktop UI or
presentation logic.

.PARAMETER ManifestPath
Absolute path to the application manifest.

.PARAMETER StateRoot
Root directory used for authoritative installed-application state.

.PARAMETER MachineArchitecture
Architecture of the machine on which the application installation will execute.

.PARAMETER DownloadRoot
Absolute root directory used for downloaded installation artifacts.

.PARAMETER PluginRoot
Root directory containing Wintainium plugins.

.PARAMETER SchemaPath
Path to the application manifest JSON schema.

.PARAMETER InstallerTimeoutMilliseconds
Maximum installer execution time in milliseconds. The default is 600000.

.PARAMETER CancellationToken
Optional cancellation token propagated through the installation lifecycle.

.OUTPUTS
PSCustomObject. The command returns the same presentation-neutral lifecycle
result shape used by the update execution boundary: OperationId,
IsSuccessful, WasCancelled, Status, ApplicationId, Stages, Errors, Warnings,
LogEvents, and Error.
#>
function Invoke-WintainiumApplicationInstall {
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

    $lifecycleParameters = @{
        ManifestPath = $ManifestPath
        StateRoot = $StateRoot
        MachineArchitecture = $MachineArchitecture
        DownloadRoot = $DownloadRoot
        PluginRoot = $PluginRoot
        SchemaPath = $SchemaPath
        InstallerTimeoutMilliseconds = $InstallerTimeoutMilliseconds
        OperationKind = 'Install'
        CancellationToken = $CancellationToken
    }

    $lifecycleResult = Invoke-WintainiumApplicationLifecycle @lifecycleParameters
    ConvertTo-WintainiumPublicApplicationUpdateResult -LifecycleResult $lifecycleResult
}
