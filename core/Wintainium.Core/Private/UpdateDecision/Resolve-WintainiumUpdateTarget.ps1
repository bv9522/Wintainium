function Resolve-WintainiumUpdateTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [psobject[]]$EligibleReleases,
        [Parameter(Mandatory)] [psobject]$Manifest,
        [Parameter(Mandatory)] [string]$MachineArchitecture
    )

    if ($null -eq $Manifest) { throw [System.ArgumentNullException]::new('Manifest') }
    if ([string]::IsNullOrWhiteSpace($MachineArchitecture)) { throw [System.ArgumentException]::new('MachineArchitecture must not be empty.') }

    $observations = [System.Collections.Generic.List[object]]::new()
    $selectable = [System.Collections.Generic.List[object]]::new()
    $inputOrder = 0

    foreach ($release in @($EligibleReleases)) {
        $artifactSelection = Select-WintainiumArtifact -Release $release -Manifest $Manifest -MachineArchitecture $MachineArchitecture
        $artifact = $artifactSelection.SelectedArtifact
        $isSelectable = $null -ne $artifact
        $reasonCode = if ($isSelectable) { 'Selectable' } else { 'NoSelectableArtifact' }
        $reason = if ($isSelectable) { 'The release has a deterministically selected artifact.' } else { 'The release has no artifact permitted for the target machine.' }
        $versionObservation = New-WintainiumVersionObservation -Version ([string]$release.Version)

        $observation = [pscustomobject][ordered]@{
            Release = $release
            SelectedArtifact = $artifact
            ArtifactSelection = $artifactSelection
            Selectable = $isSelectable
            ReasonCode = $reasonCode
            Reason = $reason
            VersionObservation = $versionObservation
            InputOrder = $inputOrder
        }
        $observations.Add($observation)
        if ($isSelectable) { $selectable.Add($observation) }
        $inputOrder++
    }

    if ($selectable.Count -eq 0) {
        return [pscustomobject][ordered]@{
            SelectedRelease = $null
            SelectedArtifact = $null
            Observations = @($observations)
            ReasonCode = 'NoSelectableArtifact'
            Reason = 'No eligible release has an artifact permitted for the target machine.'
            IsDeterministic = $true
        }
    }

    $best = $selectable[0]
    $rankingUnknown = $false
    for ($index = 1; $index -lt $selectable.Count; $index++) {
        $candidate = $selectable[$index]
        $comparison = Compare-WintainiumVersion -Left $candidate.VersionObservation -Right $best.VersionObservation

        if ($comparison.Comparison -eq 'Unknown') {
            $rankingUnknown = $true
            break
        }

        if ($comparison.Comparison -eq 'Greater') {
            $best = $candidate
        }
    }

    if ($rankingUnknown) {
        return [pscustomobject][ordered]@{
            SelectedRelease = $null
            SelectedArtifact = $null
            Observations = @($observations)
            ReasonCode = 'VersionRankingUnknown'
            Reason = 'Selectable release versions cannot be ranked without guessing.'
            IsDeterministic = $false
        }
    }

    [pscustomobject][ordered]@{
        SelectedRelease = $best.Release
        SelectedArtifact = $best.SelectedArtifact
        Observations = @($observations)
        ReasonCode = 'TargetSelected'
        Reason = 'The highest deterministically ranked eligible release with a selectable artifact was selected.'
        IsDeterministic = $true
    }
}
