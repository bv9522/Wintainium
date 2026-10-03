function Get-WintainiumApplicationInstallDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Manifest,
        [Parameter(Mandatory)] [psobject]$InstalledState,
        [Parameter(Mandatory)] [psobject]$ProviderResult,
        [Parameter(Mandatory)] [string]$MachineArchitecture,
        [Parameter()] [psobject]$Environment
    )

    if ($null -eq $Manifest) { throw [System.ArgumentNullException]::new('Manifest') }
    if ($null -eq $InstalledState) { throw [System.ArgumentNullException]::new('InstalledState') }
    if ($null -eq $ProviderResult) { throw [System.ArgumentNullException]::new('ProviderResult') }
    if ([string]::IsNullOrWhiteSpace($MachineArchitecture)) { throw [System.ArgumentException]::new('MachineArchitecture must not be empty.') }

    if ($null -eq $Environment) {
        $Environment = Get-WintainiumEnvironment -Overrides ([pscustomobject]@{ MachineArchitecture = $MachineArchitecture })
    }

    $base = [ordered]@{
        SelectedRelease = $null
        SelectedArtifact = $null
        ReleaseEligibility = $null
        TargetResolution = $null
        IsInstallAvailable = $false
        IsDeterministic = $true
    }

    if ([string]$InstalledState.InstallationState -eq 'Installed') {
        $base.Status = 'ApplicationAlreadyInstalled'
        $base.ReasonCode = 'ApplicationAlreadyInstalled'
        $base.Reason = 'The application is already installed, so no initial installation is required.'
        return [pscustomobject]$base
    }

    if ([string]$InstalledState.InstallationState -ne 'NotInstalled') {
        $base.Status = 'DecisionIndeterminate'
        $base.ReasonCode = 'InstalledStateUnknown'
        $base.Reason = 'Installed application state is not known well enough to make an initial installation decision.'
        $base.IsDeterministic = $false
        return [pscustomobject]$base
    }

    if (-not [bool]$ProviderResult.IsSuccessful) {
        $base.Status = 'ProviderDiscoveryUnsuccessful'
        $base.ReasonCode = 'ProviderDiscoveryUnsuccessful'
        $base.Reason = 'Provider discovery did not complete successfully.'
        $base.IsDeterministic = $false
        return [pscustomobject]$base
    }

    $channelPolicy = [string]$Manifest.Release.channel
    if ($channelPolicy -notin @('stable','prerelease','any')) {
        $base.Status = 'DecisionIndeterminate'
        $base.ReasonCode = 'InvalidReleasePolicy'
        $base.Reason = 'The manifest contains an unsupported release channel policy.'
        $base.IsDeterministic = $false
        return [pscustomobject]$base
    }

    $observations = [System.Collections.Generic.List[object]]::new()
    $selectable = [System.Collections.Generic.List[object]]::new()
    $inputOrder = 0

    foreach ($release in @($ProviderResult.Releases)) {
        $releaseChannel = [string]$release.Channel
        $reasonCode = $null
        $reason = $null
        $artifact = $null

        if ($releaseChannel -notin @('stable','prerelease')) {
            $reasonCode = 'UnknownReleaseChannel'
            $reason = 'The release channel is missing or unsupported.'
        }
        elseif ($channelPolicy -ne 'any' -and $releaseChannel -ne $channelPolicy) {
            $reasonCode = 'ChannelNotPermitted'
            $reason = 'The release channel is not permitted by the manifest.'
        }
        elseif ($release.PSObject.Properties.Name -contains 'Deprecated' -and $release.Deprecated -eq $true) {
            $reasonCode = 'DeprecatedRelease'
            $reason = 'The release is marked deprecated by the provider.'
        }
        elseif ([string]::IsNullOrWhiteSpace([string]$release.Version)) {
            $reasonCode = 'InsufficientVersionData'
            $reason = 'The release does not provide a usable version for deterministic installation selection.'
        }
        else {
            $artifactSelection = Select-WintainiumArtifact -Release $release -Manifest $Manifest -MachineArchitecture ([string]$Environment.MachineArchitecture)
            $artifact = $artifactSelection.SelectedArtifact
            if ($null -eq $artifact) {
                $reasonCode = 'NoSelectableArtifact'
                $reason = 'The release has no artifact permitted for the target machine.'
            }
            else {
                $reasonCode = 'Selectable'
                $reason = 'The release has a deterministically selectable artifact.'
            }
        }

        $observation = [pscustomobject][ordered]@{
            Release = $release
            SelectedArtifact = $artifact
            Selectable = ($null -ne $artifact -and $reasonCode -eq 'Selectable')
            ReasonCode = $reasonCode
            Reason = $reason
            VersionObservation = if (-not [string]::IsNullOrWhiteSpace([string]$release.Version)) { New-WintainiumVersionObservation -Version ([string]$release.Version) } else { $null }
            InputOrder = $inputOrder
        }
        $observations.Add($observation)
        if ($observation.Selectable) { $selectable.Add($observation) }
        $inputOrder++
    }

    $base.ReleaseEligibility = [pscustomobject][ordered]@{
        EligibleReleases = @($selectable | ForEach-Object Release)
        Observations = @($observations)
        IsDeterministic = $true
    }

    if ($selectable.Count -eq 0) {
        $base.Status = 'NoInstallableRelease'
        $base.ReasonCode = 'NoSelectableArtifact'
        $base.Reason = 'No discovered release has a selectable artifact for this machine.'
        return [pscustomobject]$base
    }

    $best = $selectable[0]
    $rankingUnknown = $false
    for ($index = 1; $index -lt $selectable.Count; $index++) {
        $comparison = Compare-WintainiumVersion -Left $selectable[$index].VersionObservation -Right $best.VersionObservation
        if ($comparison.Comparison -eq 'Unknown') {
            $rankingUnknown = $true
            break
        }
        if ($comparison.Comparison -eq 'Greater') {
            $best = $selectable[$index]
        }
    }

    if ($rankingUnknown) {
        $base.Status = 'DecisionIndeterminate'
        $base.ReasonCode = 'VersionRankingUnknown'
        $base.Reason = 'Selectable release versions cannot be ranked without guessing.'
        $base.IsDeterministic = $false
        return [pscustomobject]$base
    }

    $base.SelectedRelease = $best.Release
    $base.SelectedArtifact = $best.SelectedArtifact
    $base.TargetResolution = [pscustomobject][ordered]@{
        SelectedRelease = $best.Release
        SelectedArtifact = $best.SelectedArtifact
        ReasonCode = 'TargetSelected'
        Reason = 'The highest deterministically ranked eligible release with a selectable artifact was selected for installation.'
        IsDeterministic = $true
    }
    $base.Status = 'InstallAvailable'
    $base.IsInstallAvailable = $true
    $base.ReasonCode = 'InstallAvailable'
    $base.Reason = 'An installable release with a selectable artifact is available.'
    [pscustomobject]$base
}