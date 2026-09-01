function Get-WintainiumUpdateDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$UpdateDecisionInput,
        [Parameter(Mandatory)] [string]$MachineArchitecture
    )

    if ($null -eq $UpdateDecisionInput) { throw [System.ArgumentNullException]::new('UpdateDecisionInput') }
    if ([string]::IsNullOrWhiteSpace($MachineArchitecture)) { throw [System.ArgumentException]::new('MachineArchitecture must not be empty.') }

    $manifest = $UpdateDecisionInput.Manifest
    $installedState = $UpdateDecisionInput.InstalledState
    $providerResult = $UpdateDecisionInput.ProviderResult
    $base = [ordered]@{
        SelectedRelease = $null
        SelectedArtifact = $null
        ReleaseEligibility = $null
        TargetResolution = $null
    }

    if ($installedState.InstallationState -eq 'NotInstalled') {
        $base['Status']='ApplicationNotInstalled'; $base['IsUpdateAvailable']=$false; $base['ReasonCode']='ApplicationNotInstalled'; $base['Reason']='The application is not installed, so no update decision is made.'; $base['IsDeterministic']=$true
        return [pscustomobject]$base
    }

    if ($installedState.InstallationState -ne 'Installed') {
        $base['Status']='DecisionIndeterminate'; $base['IsUpdateAvailable']=$null; $base['ReasonCode']='InstalledStateUnknown'; $base['Reason']='Installed application state is not known well enough to make an update decision.'; $base['IsDeterministic']=$false
        return [pscustomobject]$base
    }

    if (-not [bool]$providerResult.IsSuccessful) {
        $base['Status']='ProviderDiscoveryUnsuccessful'; $base['IsUpdateAvailable']=$null; $base['ReasonCode']='ProviderDiscoveryUnsuccessful'; $base['Reason']='Provider discovery did not complete successfully.'; $base['IsDeterministic']=$false
        return [pscustomobject]$base
    }

    $eligibility = Get-WintainiumEligibleRelease -Releases @($providerResult.Releases) -Manifest $manifest -InstalledState $installedState
    $target = Resolve-WintainiumUpdateTarget -EligibleReleases @($eligibility.EligibleReleases) -Manifest $manifest -MachineArchitecture $MachineArchitecture
    $base.ReleaseEligibility = $eligibility
    $base.TargetResolution = $target

    if ($target.ReasonCode -eq 'TargetSelected') {
        $base['SelectedRelease']=$target.SelectedRelease; $base['SelectedArtifact']=$target.SelectedArtifact; $base['Status']='UpdateAvailable'; $base['IsUpdateAvailable']=$true; $base['ReasonCode']='UpdateAvailable'; $base['Reason']='A newer eligible release with a selectable artifact is available.'; $base['IsDeterministic']=$true
        return [pscustomobject]$base
    }

    if ($target.ReasonCode -eq 'VersionRankingUnknown') {
        $base['Status']='DecisionIndeterminate'; $base['IsUpdateAvailable']=$null; $base['ReasonCode']='VersionRankingUnknown'; $base['Reason']='Selectable release versions cannot be ranked without guessing.'; $base['IsDeterministic']=$false
        return [pscustomobject]$base
    }

    $reasonCode = if (@($eligibility.EligibleReleases).Count -eq 0) { 'NoEligibleRelease' } else { 'NoSelectableArtifact' }
    $reason = if ($reasonCode -eq 'NoEligibleRelease') { 'No discovered release is eligible as an update.' } else { 'Eligible releases exist, but none has a selectable artifact.' }
    $base['Status']='NoUpdateAvailable'; $base['IsUpdateAvailable']=$false; $base['ReasonCode']=$reasonCode; $base['Reason']=$reason; $base['IsDeterministic']=$true
    [pscustomobject]$base
}
