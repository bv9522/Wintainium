<#
.SYNOPSIS
Refreshes authoritative installed state for one managed application.

.DESCRIPTION
Validates the application's manifest, resolves its declared reconciliation
plugin, obtains fresh installed-application evidence, and persists trustworthy
evidence through Core's authoritative state boundary. Unknown evidence never
overwrites an existing trustworthy state.
#>
function Invoke-WintainiumApplicationReconciliation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ManifestPath,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$StateRoot,
        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),
        [string]$OperationId
    )

    $validation = Test-WintainiumApplicationDefinition -ManifestPath $ManifestPath -PluginRoot $PluginRoot -SchemaPath $SchemaPath -OperationId $OperationId
    $resolvedOperationId = [string]$validation.OperationId

    if (-not $validation.IsValid) {
        return [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId; IsSuccessful=$false; Status='ApplicationDefinitionInvalid'
            ApplicationId=if($null -ne $validation.Manifest){[string]$validation.Manifest.Id}else{$null}
            State=$null; Reconciliation=$null
            Errors=@($validation.Errors); Warnings=@($validation.Warnings); LogEvents=@($validation.LogEvents)
        }
    }

    $manifest = $validation.Manifest
    $applicationId = [string]$manifest.Id
    $plugin = $validation.ReconciliationPlugin
    if ($null -eq $plugin) {
        return [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId; IsSuccessful=$false; Status='ReconciliationUnavailable'
            ApplicationId=$applicationId; State=$null; Reconciliation=$null
            Errors=@([pscustomobject][ordered]@{
                Code='ReconciliationPluginUnavailable'; Path='$.reconciliation.pluginId'
                Message='The validated application manifest does not provide a resolvable reconciliation plugin.'
            })
            Warnings=@($validation.Warnings); LogEvents=@($validation.LogEvents)
        }
    }

    try {
        $priorState = Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId $applicationId
    }
    catch {
        return [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId; IsSuccessful=$false; Status='InstalledStateUnavailable'
            ApplicationId=$applicationId; State=$null; Reconciliation=$null
            Errors=@([pscustomobject][ordered]@{
                Code='InstalledStateReadFailed'; Path='$.StateRoot'; Message=$_.Exception.Message
            })
            Warnings=@($validation.Warnings); LogEvents=@($validation.LogEvents)
        }
    }

    $request = [pscustomobject][ordered]@{
        OperationId=$resolvedOperationId; ApplicationId=$applicationId; Manifest=$manifest; PriorState=$priorState
    }

    $reconciliation = Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $plugin -Request $request
    if (-not [bool]$reconciliation.IsSuccessful) {
        return [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId; IsSuccessful=$false; Status=[string]$reconciliation.Status
            ApplicationId=$applicationId; State=$priorState; Reconciliation=$reconciliation
            Errors=@($reconciliation.Errors)
            Warnings=@($validation.Warnings)+@($reconciliation.Warnings)
            LogEvents=@($validation.LogEvents)+@($reconciliation.LogEvents)
        }
    }

    $authoritative = Invoke-WintainiumAuthoritativeStateReconciliation -StateRoot $StateRoot -OperationId $resolvedOperationId -ApplicationId $applicationId -ReconciliationResult $reconciliation -PriorState $priorState
    if (-not [bool]$authoritative.IsSuccessful) {
        return [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId; IsSuccessful=$false; Status='AuthoritativeStateReconciliationFailed'
            ApplicationId=$applicationId; State=$authoritative.State; Reconciliation=$reconciliation
            Errors=@($authoritative.Errors)
            Warnings=@($validation.Warnings)+@($reconciliation.Warnings)
            LogEvents=@($validation.LogEvents)+@($reconciliation.LogEvents)
        }
    }

    [pscustomobject][ordered]@{
        OperationId=$resolvedOperationId; IsSuccessful=$true; Status=[string]$authoritative.Status
        ApplicationId=$applicationId; State=$authoritative.State; Reconciliation=$reconciliation
        Errors=@(); Warnings=@($validation.Warnings)+@($reconciliation.Warnings)
        LogEvents=@($validation.LogEvents)+@($reconciliation.LogEvents)
    }
}
