function Select-WintainiumArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Release,
        [Parameter(Mandatory)] [psobject]$Manifest,
        [Parameter(Mandatory)] [string]$MachineArchitecture
    )

    if ($null -eq $Release) { throw [System.ArgumentNullException]::new('Release') }
    if ($null -eq $Manifest) { throw [System.ArgumentNullException]::new('Manifest') }

    $observations = [System.Collections.Generic.List[object]]::new()
    $index = 0
    foreach ($artifact in @($Release.Artifacts)) {
        $observation = Test-WintainiumArtifactEligibility -Artifact $artifact -Manifest $Manifest -MachineArchitecture $MachineArchitecture
        $observations.Add([pscustomobject][ordered]@{
            Artifact = $observation.Artifact
            Eligible = $observation.Eligible
            ReasonCode = $observation.ReasonCode
            Reason = $observation.Reason
            Format = $observation.Format
            Architecture = $observation.Architecture
            InputOrder = $index
        })
        $index++
    }

    $eligible = @($observations | Where-Object Eligible)
    $selected = $null

    if ($eligible.Count -gt 0) {
        $formats = @($Manifest.artifact.formats | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
        $machine = $MachineArchitecture.Trim().ToLowerInvariant()

        $ranked = foreach ($item in $eligible) {
            $architectureRank = switch ($item.Architecture) {
                $machine { 0 }
                'neutral' { 1 }
                'unknown' { 2 }
                default { 3 }
            }
            $formatRank = [array]::IndexOf($formats, $item.Format)
            if ($formatRank -lt 0) { $formatRank = [int]::MaxValue }

            [pscustomobject]@{
                Item = $item
                ArchitectureRank = $architectureRank
                FormatRank = $formatRank
                InputOrder = $item.InputOrder
            }
        }

        $selected = ($ranked | Sort-Object ArchitectureRank, FormatRank, InputOrder | Select-Object -First 1).Item.Artifact
    }

    [pscustomobject][ordered]@{
        SelectedArtifact = $selected
        Observations = @($observations)
        IsDeterministic = $true
    }
}
