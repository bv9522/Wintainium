function Test-WintainiumArtifactEligibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Artifact,
        [Parameter(Mandatory)] [psobject]$Manifest,
        [Parameter(Mandatory)] [string]$MachineArchitecture
    )

    if ($null -eq $Artifact) { throw [System.ArgumentNullException]::new('Artifact') }
    if ($null -eq $Manifest) { throw [System.ArgumentNullException]::new('Manifest') }
    if ([string]::IsNullOrWhiteSpace($MachineArchitecture)) { throw [System.ArgumentException]::new('MachineArchitecture is required.') }

    $artifactPolicy = $Manifest.PSObject.Properties['artifact']?.Value
    if ($null -eq $artifactPolicy) {
        return [pscustomobject][ordered]@{ Artifact=$Artifact; Eligible=$false; ReasonCode='ArtifactPolicyMissing'; Reason='Manifest artifact policy is missing.'; Format=$null; Architecture=$null }
    }

    $rawFormat = if ($Artifact.PSObject.Properties['Format']) { [string]$Artifact.Format } else { '' }
    $rawArchitecture = if ($Artifact.PSObject.Properties['Architecture']) { [string]$Artifact.Architecture } else { '' }
    $format = $rawFormat.Trim().ToLowerInvariant()
    $architecture = $rawArchitecture.Trim().ToLowerInvariant()
    $machine = $MachineArchitecture.Trim().ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace($format)) {
        return [pscustomobject][ordered]@{ Artifact=$Artifact; Eligible=$false; ReasonCode='FormatMissing'; Reason='Artifact format is missing.'; Format=$null; Architecture=if ($architecture) { $architecture } else { $null } }
    }

    $formats = @($artifactPolicy.formats | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
    if ($format -notin $formats) {
        return [pscustomobject][ordered]@{ Artifact=$Artifact; Eligible=$false; ReasonCode='FormatNotPermitted'; Reason='Artifact format is not permitted by the manifest.'; Format=$format; Architecture=if ($architecture) { $architecture } else { $null } }
    }

    if ([string]::IsNullOrWhiteSpace($architecture)) {
        return [pscustomobject][ordered]@{ Artifact=$Artifact; Eligible=$false; ReasonCode='ArchitectureMissing'; Reason='Artifact architecture is missing.'; Format=$format; Architecture=$null }
    }

    $allowedArchitectures = @($artifactPolicy.architectures | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
    $unknownAllowed = $architecture -eq 'unknown' -and [bool]$artifactPolicy.allowUnknownArchitecture
    if (-not $unknownAllowed -and $architecture -notin $allowedArchitectures) {
        return [pscustomobject][ordered]@{ Artifact=$Artifact; Eligible=$false; ReasonCode='ArchitectureNotPermitted'; Reason='Artifact architecture is not permitted by the manifest.'; Format=$format; Architecture=$architecture }
    }

    $compatible = $architecture -eq 'neutral' -or $architecture -eq $machine -or $unknownAllowed
    if (-not $compatible) {
        return [pscustomobject][ordered]@{ Artifact=$Artifact; Eligible=$false; ReasonCode='ArchitectureIncompatible'; Reason='Artifact architecture is incompatible with the target machine.'; Format=$format; Architecture=$architecture }
    }

    [pscustomobject][ordered]@{ Artifact=$Artifact; Eligible=$true; ReasonCode='Eligible'; Reason='Artifact satisfies the manifest and machine compatibility policy.'; Format=$format; Architecture=$architecture }
}
