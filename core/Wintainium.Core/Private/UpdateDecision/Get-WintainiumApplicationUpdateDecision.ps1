function Get-WintainiumApplicationUpdateDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StateRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$MachineArchitecture,

        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,

        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json')
    )

    if ([string]::IsNullOrWhiteSpace($StateRoot)) {
        throw [System.ArgumentException]::new('StateRoot must not be empty or whitespace.')
    }

    $releaseResult = Get-WintainiumApplicationRelease -ManifestPath $ManifestPath -PluginRoot $PluginRoot -SchemaPath $SchemaPath
    if (-not $releaseResult.IsSuccessful) {
        return [pscustomobject][ordered]@{
            OperationId = $releaseResult.OperationId
            IsSuccessful = $false
            Status = 'ProviderDiscoveryUnsuccessful'
            Manifest = $releaseResult.Manifest
            InstalledState = $null
            Decision = $null
            Errors = @($releaseResult.Errors)
            Warnings = @($releaseResult.Warnings)
            LogEvents = @($releaseResult.LogEvents)
        }
    }

    $manifest = $releaseResult.Manifest
    $installedState = Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId ([string]$manifest.Id)
    $providerResult = [pscustomobject][ordered]@{
        IsSuccessful = $releaseResult.IsSuccessful
        Status = $releaseResult.Status
        Releases = @($releaseResult.Releases)
        Errors = @($releaseResult.Errors)
        Warnings = @($releaseResult.Warnings)
        LogEvents = @($releaseResult.LogEvents)
    }

    $decisionInput = New-WintainiumUpdateDecisionInput -Manifest $manifest -InstalledState $installedState -ProviderResult $providerResult
    $decision = Get-WintainiumUpdateDecision -UpdateDecisionInput $decisionInput -MachineArchitecture $MachineArchitecture

    [pscustomobject][ordered]@{
        OperationId = $releaseResult.OperationId
        IsSuccessful = $true
        Status = [string]$decision.Status
        Manifest = $manifest
        InstalledState = $installedState
        Decision = $decision
        Errors = @($releaseResult.Errors)
        Warnings = @($releaseResult.Warnings)
        LogEvents = @($releaseResult.LogEvents)
    }
}
