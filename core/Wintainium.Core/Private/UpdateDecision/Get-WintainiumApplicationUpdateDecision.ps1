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

    if ([string]::IsNullOrWhiteSpace($StateRoot)) { throw [System.ArgumentException]::new('StateRoot must not be empty or whitespace.') }

    $releaseResult = Get-WintainiumApplicationRelease -ManifestPath $ManifestPath -PluginRoot $PluginRoot -SchemaPath $SchemaPath -OperationId $OperationId
    if (-not $releaseResult.IsSuccessful) {
        return [pscustomobject][ordered]@{ OperationId=$releaseResult.OperationId; IsSuccessful=$false; Status='ProviderDiscoveryUnsuccessful'; Manifest=$releaseResult.Manifest; InstalledState=$null; Decision=$null; Errors=@($releaseResult.Errors); Warnings=@($releaseResult.Warnings); LogEvents=@($releaseResult.LogEvents) }
    }

    $manifest = $releaseResult.Manifest

    # Update status is an authoritative observation, not a read of potentially stale
    # persisted state. Refresh installed state through the Core reconciliation boundary
    # before evaluating whether a newer release is applicable.
    $reconciliationParameters = @{
        ManifestPath = $ManifestPath
        StateRoot = $StateRoot
        PluginRoot = $PluginRoot
        SchemaPath = $SchemaPath
        OperationId = $releaseResult.OperationId
    }
    $reconciliation = Invoke-WintainiumApplicationReconciliation @reconciliationParameters

    if (-not [bool]$reconciliation.IsSuccessful) {
        return [pscustomobject][ordered]@{
            OperationId=$releaseResult.OperationId
            IsSuccessful=$false
            Status='InstalledStateReconciliationUnsuccessful'
            Manifest=$manifest
            InstalledState=$reconciliation.State
            Decision=$null
            Errors=@($reconciliation.Errors)
            Warnings=@($releaseResult.Warnings)+@($reconciliation.Warnings)
            LogEvents=@($releaseResult.LogEvents)+@($reconciliation.LogEvents)
        }
    }

    $installedState = $reconciliation.State
    $providerResult = [pscustomobject][ordered]@{
        IsSuccessful=$releaseResult.IsSuccessful
        Status=$releaseResult.Status
        Releases=@($releaseResult.Releases)
        Errors=@($releaseResult.Errors)
        Warnings=@($releaseResult.Warnings)+@($reconciliation.Warnings)
        LogEvents=@($releaseResult.LogEvents)+@($reconciliation.LogEvents)
    }
    $decisionInput = New-WintainiumUpdateDecisionInput -Manifest $manifest -InstalledState $installedState -ProviderResult $providerResult
    $decision = Get-WintainiumUpdateDecision -UpdateDecisionInput $decisionInput -MachineArchitecture $MachineArchitecture

    $logEvents = [System.Collections.Generic.List[object]]::new()
    foreach ($event in @($releaseResult.LogEvents)) { $logEvents.Add($event) }
    foreach ($event in @($reconciliation.LogEvents)) { $logEvents.Add($event) }

    if ($null -ne $decision.ReleaseEligibility -and @($decision.ReleaseEligibility.Observations).Count -gt 0) {
        $releaseEligibilityObservations = @(
            foreach ($observation in @($decision.ReleaseEligibility.Observations)) {
                [pscustomobject][ordered]@{
                    ReleaseVersion = [string]$observation.Release.Version
                    ReleaseChannel = [string]$observation.Release.Channel
                    Eligible = [bool]$observation.Eligible
                    ReasonCode = [string]$observation.ReasonCode
                    Reason = [string]$observation.Reason
                    VersionComparison = if ($null -ne $observation.VersionComparison) { [string]$observation.VersionComparison.Comparison } else { $null }
                    ComparisonStrategy = if ($null -ne $observation.VersionComparison) { [string]$observation.VersionComparison.Strategy } else { $null }
                }
            }
        )
        # Flatten target/artifact eligibility into an explicitly safe diagnostic shape.
        # Artifact URLs are never copied into diagnostics; only the final path segment is retained.
        $targetObservations = @(
            foreach ($targetObservation in @($decision.TargetResolution.Observations)) {
                $artifactObservations = @(
                    foreach ($artifactObservation in @($targetObservation.ArtifactSelection.Observations)) {
                        $artifactName = $null
                        $artifactUri = [string]$artifactObservation.Artifact.Uri
                        if (-not [string]::IsNullOrWhiteSpace($artifactUri)) {
                            try {
                                $parsedArtifactUri = [uri]$artifactUri
                                $artifactName = [System.IO.Path]::GetFileName($parsedArtifactUri.AbsolutePath)
                            }
                            catch {
                                $artifactName = [System.IO.Path]::GetFileName(($artifactUri -split '[?#]', 2)[0])
                            }
                        }

                        [pscustomobject][ordered]@{
                            ArtifactName = [string]$artifactName
                            Format = [string]$artifactObservation.Format
                            Architecture = [string]$artifactObservation.Architecture
                            Eligible = [bool]$artifactObservation.Eligible
                            ReasonCode = [string]$artifactObservation.ReasonCode
                            Reason = [string]$artifactObservation.Reason
                        }
                    }
                )

                [pscustomobject][ordered]@{
                    ReleaseVersion = [string]$targetObservation.Release.Version
                    Selectable = [bool]$targetObservation.Selectable
                    ReasonCode = [string]$targetObservation.ReasonCode
                    Reason = [string]$targetObservation.Reason
                    Artifacts = $artifactObservations
                }
            }
        )
        $severity = if ($decision.Status -eq 'DecisionIndeterminate') { 'Warning' } else { 'Information' }
        $logEvents.Add((New-WintainiumLogEvent -Severity $severity -OperationId $releaseResult.OperationId -Component 'CoreUpdateDecision' -EventName 'ReleaseEligibilityEvaluated' -Message 'Release candidates and their artifacts were evaluated against the installed version, manifest policy, and target architecture.' -Context @{
            ApplicationId = [string]$manifest.Id
            InstalledVersion = [string]$installedState.Version
            InstalledVersionSource = [string]$installedState.VersionSource
            ManifestChannelPolicy = [string]$manifest.Release.channel
            DecisionStatus = [string]$decision.Status
            DecisionReasonCode = [string]$decision.ReasonCode
            ReleaseObservations = $releaseEligibilityObservations
            TargetObservations = $targetObservations
        }))
    }

    [pscustomobject][ordered]@{ OperationId=$releaseResult.OperationId; IsSuccessful=$true; Status=[string]$decision.Status; Manifest=$manifest; InstalledState=$installedState; Decision=$decision; Errors=@($releaseResult.Errors); Warnings=@($releaseResult.Warnings); LogEvents=$logEvents.ToArray() }
}
