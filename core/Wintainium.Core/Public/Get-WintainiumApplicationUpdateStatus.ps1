<#
.SYNOPSIS
Returns the Core-owned application update status for presentation clients.

.DESCRIPTION
Validates the application manifest, discovers releases, reads authoritative
installed state, and evaluates the Core update-decision pipeline. This command
does not download, verify, install, or reconcile the application. The detailed
update decision remains an internal Core concern; this public boundary exposes
the structured observations required by presentation clients.

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
function Get-WintainiumApplicationUpdateStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$ManifestPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$StateRoot,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$MachineArchitecture,
        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),
        [string]$OperationId
    )

    $result = Get-WintainiumApplicationUpdateDecision -ManifestPath $ManifestPath -StateRoot $StateRoot -MachineArchitecture $MachineArchitecture -PluginRoot $PluginRoot -SchemaPath $SchemaPath -OperationId $OperationId

    $decision = $null
    if ($null -ne $result.Decision) {
        $selectedRelease = $result.Decision.SelectedRelease
        $decision = [pscustomobject][ordered]@{
            IsUpdateAvailable = $result.Decision.IsUpdateAvailable
            ReasonCode = $result.Decision.ReasonCode
            Reason = $result.Decision.Reason
            IsDeterministic = $result.Decision.IsDeterministic
            SelectedRelease = if ($null -eq $selectedRelease) {
                $null
            }
            else {
                [pscustomobject][ordered]@{
                    ReleaseId = [string]$selectedRelease.ReleaseId
                    Version = [string]$selectedRelease.Version
                    Channel = [string]$selectedRelease.Channel
                    PublishedAt = $selectedRelease.PublishedAt
                }
            }
        }
    }

    [pscustomobject][ordered]@{
        OperationId = $result.OperationId
        IsSuccessful = $result.IsSuccessful
        Status = $result.Status
        Manifest = $result.Manifest
        InstalledState = $result.InstalledState
        Decision = $decision
        Errors = @($result.Errors)
        Warnings = @($result.Warnings)
        LogEvents = @($result.LogEvents)
    }
}
