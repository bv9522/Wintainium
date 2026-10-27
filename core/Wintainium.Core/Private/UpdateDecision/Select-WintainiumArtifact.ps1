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

        if ($observation.Architecture -eq 'unknown') {
            $artifactHashes = if ($artifact.PSObject.Properties['Hashes']) { $artifact.Hashes } else { $null }
            $hasIntegrityHash = $false

            if ($artifactHashes -is [System.Collections.IDictionary]) {
                foreach ($hashName in @($artifactHashes.Keys)) {
                    $algorithm = [string]$hashName
                    $value = [string]$artifactHashes[$hashName]
                    if (($algorithm -ieq 'SHA256' -and $value -match '^[0-9A-Fa-f]{64}$') -or
                        ($algorithm -ieq 'MD5' -and $value -match '^[0-9A-Fa-f]{32}$')) {
                        $hasIntegrityHash = $true
                        break
                    }
                }
            }
            else {
                $hasIntegrityHash = @($artifactHashes | Where-Object {
                    $null -ne $_ -and $_.PSObject.Properties['Algorithm'] -and $_.PSObject.Properties['Value'] -and
                    (([string]$_.Algorithm -ieq 'SHA256' -and [string]$_.Value -match '^[0-9A-Fa-f]{64}$') -or
                     ([string]$_.Algorithm -ieq 'MD5' -and [string]$_.Value -match '^[0-9A-Fa-f]{32}$'))
                }).Count -gt 0
            }

            $manifestFormats = @($Manifest.artifact.formats | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
            $manifestArchitectures = @($Manifest.artifact.architectures | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
            if ($hasIntegrityHash -and $observation.Format -in $manifestFormats -and $targetArchitecture.Trim().ToLowerInvariant() -in $manifestArchitectures) {
                $inspectionCandidate = $true
                $reasonCode = 'ArchitectureInspectionRequired'
                $reason = 'The unknown-architecture artifact has publisher checksum evidence and may be considered only after successful checksum verification and an explicit architecture-risk decision.'
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

    $eligible = @($observations | Where-Object { ($_.Eligible -and $_.Architecture -ne 'unknown') -or $_.ArchitectureInspectionCandidate })
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

function Get-WintainiumArchitectureRiskFallbackReleases {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Releases)

    foreach ($release in $Releases) {
        if ($null -eq $release) { continue }
        $properties = [ordered]@{}
        foreach ($property in $release.PSObject.Properties) {
            $properties[$property.Name] = $property.Value
        }
        $properties['Artifacts'] = @($release.Artifacts | Where-Object {
            [string]$_.Architecture -ne 'unknown'
        })
        [pscustomobject]$properties
    }
}

function Test-WintainiumArtifactHasSupportedChecksum {
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$Artifact)

    if ($null -eq $Artifact -or -not $Artifact.PSObject.Properties['Hashes']) { return $false }
    $hashes = $Artifact.Hashes
    if ($hashes -is [System.Collections.IDictionary]) {
        foreach ($name in $hashes.Keys) {
            $algorithm = [string]$name
            $value = [string]$hashes[$name]
            if (($algorithm -ieq 'SHA256' -and $value -match '^[0-9A-Fa-f]{64}$') -or
                ($algorithm -ieq 'MD5' -and $value -match '^[0-9A-Fa-f]{32}$')) {
                return $true
            }
        }
        return $false
    }

    return @($hashes | Where-Object {
        $null -ne $_ -and $_.PSObject.Properties['Algorithm'] -and $_.PSObject.Properties['Value'] -and
        (([string]$_.Algorithm -ieq 'SHA256' -and [string]$_.Value -match '^[0-9A-Fa-f]{64}$') -or
         ([string]$_.Algorithm -ieq 'MD5' -and [string]$_.Value -match '^[0-9A-Fa-f]{32}$'))
    }).Count -gt 0
}
