function Test-WintainiumReleaseEligibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Release,
        [Parameter(Mandatory)]
        [psobject]$Manifest,
        [Parameter(Mandatory)]
        [psobject]$InstalledState
    )

    $channelPolicy = [string]$Manifest.Release.channel
    $releaseChannel = [string]$Release.Channel

    if ([string]::IsNullOrWhiteSpace($releaseChannel) -or $releaseChannel -notin @('stable','prerelease')) {
        return [pscustomobject][ordered]@{ Eligible = $false; ReasonCode = 'UnknownReleaseChannel'; Reason = 'The release channel is missing or unsupported.'; Release = $Release; VersionComparison = $null }
    }

    if ($channelPolicy -eq 'stable' -and $releaseChannel -ne 'stable') {
        return [pscustomobject][ordered]@{ Eligible = $false; ReasonCode = 'ChannelNotPermitted'; Reason = 'The manifest permits stable releases only.'; Release = $Release; VersionComparison = $null }
    }

    if ($channelPolicy -eq 'prerelease' -and $releaseChannel -ne 'prerelease') {
        return [pscustomobject][ordered]@{ Eligible = $false; ReasonCode = 'ChannelNotPermitted'; Reason = 'The manifest permits prerelease releases only.'; Release = $Release; VersionComparison = $null }
    }

    if ($Release.PSObject.Properties.Name -contains 'Deprecated' -and $Release.Deprecated -eq $true) {
        return [pscustomobject][ordered]@{ Eligible = $false; ReasonCode = 'DeprecatedRelease'; Reason = 'The release is marked deprecated by the provider.'; Release = $Release; VersionComparison = $null }
    }

    $installedVersion = $InstalledState.Version
    $releaseVersion = $Release.Version
    if ([string]::IsNullOrWhiteSpace([string]$installedVersion) -or [string]::IsNullOrWhiteSpace([string]$releaseVersion)) {
        return [pscustomobject][ordered]@{ Eligible = $false; ReasonCode = 'InsufficientVersionData'; Reason = 'Installed or release version data is unavailable.'; Release = $Release; VersionComparison = $null }
    }

    $installedObservation = New-WintainiumVersionObservation -Version ([string]$installedVersion)
    $releaseObservation = New-WintainiumVersionObservation -Version ([string]$releaseVersion)
    $comparison = Compare-WintainiumVersion -Left $installedObservation -Right $releaseObservation

    if ($comparison.Result -ne 'Greater') {
        $reasonCode = switch ($comparison.Result) {
            'Equal' { 'NotNewer' }
            'Less' { 'DowngradeNotPermitted' }
            default { 'VersionComparisonUnknown' }
        }
        return [pscustomobject][ordered]@{ Eligible = $false; ReasonCode = $reasonCode; Reason = "The release version does not establish a newer compatible version."; Release = $Release; VersionComparison = $comparison }
    }

    [pscustomobject][ordered]@{ Eligible = $true; ReasonCode = 'Eligible'; Reason = 'The release satisfies the applicable channel and version eligibility rules.'; Release = $Release; VersionComparison = $comparison }
}
