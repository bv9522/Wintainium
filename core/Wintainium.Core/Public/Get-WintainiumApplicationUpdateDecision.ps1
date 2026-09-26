<#
.SYNOPSIS
Returns the Core-owned update decision for one application.

.DESCRIPTION
Validates the application manifest, discovers releases, reads authoritative
installed state, and evaluates the Core update-decision pipeline. This command
does not download, verify, install, or reconcile the application.

.PARAMETER ManifestPath
Absolute path to the application manifest.

.PARAMETER StateRoot
Root directory containing authoritative installed-application state.

.PARAMETER MachineArchitecture
Normalized target-machine architecture used by Core target resolution.

.PARAMETER PluginRoot
Root directory containing Wintainium plugins.

.PARAMETER SchemaPath
Path to the application manifest JSON schema.

.PARAMETER OperationId
Optional lifecycle correlation identifier. When supplied, it is preserved.

.OUTPUTS
PSCustomObject. The result contains OperationId, IsSuccessful, Status,
Manifest, InstalledState, Decision, Errors, Warnings, and LogEvents.
#>
function Get-WintainiumApplicationUpdateDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$ManifestPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$StateRoot,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$MachineArchitecture,
        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),
        [string]$OperationId
    )

    Get-WintainiumApplicationUpdateDecision -ManifestPath $ManifestPath -StateRoot $StateRoot -MachineArchitecture $MachineArchitecture -PluginRoot $PluginRoot -SchemaPath $SchemaPath -OperationId $OperationId
}
