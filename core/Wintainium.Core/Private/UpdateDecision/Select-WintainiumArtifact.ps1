function Select-WintainiumArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Release,
        [Parameter(Mandatory)] [psobject]$Manifest,
        [Parameter(Mandatory)] [string]$MachineArchitecture,
        [Parameter()] [psobject]$Environment
    )

    if ($null -eq $Release) { throw [System.ArgumentNullException]::new('Release') }
    if ($null -eq $Manifest) { throw [System.ArgumentNullException]::new('Manifest') }
    if ($null -eq $Environment) { $Environment = Get-WintainiumEnvironment -Overrides ([pscustomobject]@{ MachineArchitecture=$MachineArchitecture }) }
    if ($Environment.PSObject.Properties.Name -notcontains 'MachineArchitecture' -or [string]::IsNullOrWhiteSpace([string]$Environment.MachineArchitecture)) { throw [System.ArgumentException]::new('Environment must contain a non-empty MachineArchitecture.') }
    $targetArchitecture = [string]$Environment.MachineArchitecture

    $observations = [System.Collections.Generic.List[object]]::new()
    $index = 0
    foreach ($artifact in @($Release.Artifacts)) {
        $observation = Test-WintainiumArtifactEligibility -Artifact $artifact -Manifest $Manifest -MachineArchitecture $targetArchitecture
        $reasonCode = $observation.ReasonCode
        $reason = $observation.Reason
        $inspectionCandidate = $false
        if ($reasonCode -eq 'ArchitectureNotPermitted' -and
            $observation.Architecture -eq 'unknown' -and
            $observation.Format -eq 'exe' -and
            (Test-WintainiumInstallerArchitectureInspectionAvailable)) {
            $artifactHashes = if ($artifact.PSObject.Properties['Hashes']) { $artifact.Hashes } else { $null }
            $hasSha256 = $false
            if ($artifactHashes -is [System.Collections.IDictionary]) {
                $sha256Key = @($artifactHashes.Keys | Where-Object { [string]$_ -ieq 'SHA256' } | Select-Object -First 1)
                if ($sha256Key.Count -gt 0) {
                    $hasSha256 = [string]$artifactHashes[$sha256Key[0]] -match '^[0-9A-Fa-f]{64}$'
                }
            } else {
                $hasSha256 = @($artifactHashes | Where-Object {
                    $null -ne $_ -and $_.PSObject.Properties['Algorithm'] -and [string]$_.Algorithm -ieq 'SHA256' -and
                    $_.PSObject.Properties['Value'] -and [string]$_.Value -match '^[0-9A-Fa-f]{64}$'
                }).Count -gt 0
            }
            $manifestFormats = @($Manifest.artifact.formats | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
            $manifestArchitectures = @($Manifest.artifact.architectures | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
            if ($hasSha256 -and 'exe' -in $manifestFormats -and $targetArchitecture.Trim().ToLowerInvariant() -in $manifestArchitectures) {
                $inspectionCandidate = $true
                $reasonCode = 'ArchitectureInspectionRequired'
                $reason = 'The unknown-architecture executable has SHA256 evidence and will be inspected after download verification.'
            }
        }
        if ($reasonCode -eq 'ArchitectureNotPermitted' -and $observation.Architecture -ne 'unknown') {
            $reasonCode = 'ArchitectureIncompatible'
            $reason = 'Artifact architecture is incompatible with the target machine.'
        }

        $observations.Add([pscustomobject][ordered]@{
            Artifact = $observation.Artifact
            Eligible = $observation.Eligible
            ArchitectureInspectionCandidate = $inspectionCandidate
            ReasonCode = $reasonCode
            Reason = $reason
            Format = $observation.Format
            Architecture = $observation.Architecture
            InputOrder = $index
        })
        $index++
    }

    $eligible = @($observations | Where-Object { $_.Eligible -or $_.ArchitectureInspectionCandidate })
    $selected = $null

    if ($eligible.Count -gt 0) {
        $formats = @($Manifest.artifact.formats | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
        $machine = $targetArchitecture.Trim().ToLowerInvariant()

        $ranked = foreach ($item in $eligible) {
            $architectureRank = if ($item.ArchitectureInspectionCandidate) { -1 } else {
                switch ($item.Architecture) {
                    $machine { 0 }
                    'neutral' { 1 }
                    'unknown' { 2 }
                    default { 3 }
                }
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

        $selectedObservation = ($ranked | Sort-Object ArchitectureRank, FormatRank, InputOrder | Select-Object -First 1).Item
        $selected = $selectedObservation.Artifact
        if ($selectedObservation.ArchitectureInspectionCandidate) {
            $selected | Add-Member -NotePropertyName ArchitectureInspectionRequired -NotePropertyValue $true -Force
        }
    }

    [pscustomobject][ordered]@{
        SelectedArtifact = $selected
        Observations = @($observations)
        IsDeterministic = $true
    }
}
