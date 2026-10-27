function Get-WintainiumPortableExecutableArchitecture {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 'unknown' }
    $stream = $null
    $reader = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        if ($stream.Length -lt 64) { return 'unknown' }
        $reader = [System.IO.BinaryReader]::new($stream)
        if ($reader.ReadUInt16() -ne 0x5A4D) { return 'unknown' }
        $stream.Position = 0x3C
        $peOffset = [int64]$reader.ReadInt32()
        if ($peOffset -lt 0 -or $peOffset -gt ($stream.Length - 6)) { return 'unknown' }
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) { return 'unknown' }
        switch ([int]$reader.ReadUInt16()) {
            0x014C { return 'x86' }
            0x8664 { return 'x64' }
            0xAA64 { return 'arm64' }
            default { return 'unknown' }
        }
    }
    catch { return 'unknown' }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        elseif ($null -ne $stream) { $stream.Dispose() }
    }
}

function Resolve-WintainiumInstallerPayloadArchitecture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$DownloadResult,
        [Parameter(Mandatory)][psobject]$SelectedArtifact,
        [Parameter(Mandatory)][psobject]$VerificationResult,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$MachineArchitecture
    )

    $path = if ($null -ne $DownloadResult -and $DownloadResult.PSObject.Properties['DestinationPath']) { [string]$DownloadResult.DestinationPath } else { '' }
    $validVerification = $null -ne $DownloadResult -and [string]$DownloadResult.Status -eq 'Downloaded' -and
        ([string]$VerificationResult.Status -in @('Verified','VerifiedWithReducedAssurance')) -and ([string]$VerificationResult.Algorithm -in @('SHA256','MD5'))
    if (-not $validVerification) {
        return [pscustomobject][ordered]@{
            IsSuccessful=$false; Status='Unresolved'; ReasonCode='VerifiedArtifactRequired'
            Reason='Architecture risk evaluation requires a completed download that passed an explicitly supported checksum verification.'
            PayloadArchitectures=@(); ResolvedArchitecture=$null; Inspector='native-static'
        }
    }
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return [pscustomobject][ordered]@{
            IsSuccessful=$false; Status='Unresolved'; ReasonCode='ArtifactPathMissing'
            Reason='The verified installer file is unavailable.'
            PayloadArchitectures=@(); ResolvedArchitecture=$null; Inspector='native-static'
        }
    }

    # Reading the outer PE header is safe and useful evidence, but a bootstrapper's
    # machine type does not prove the architecture of the application it installs.
    # Without a supported native payload parser, keep payload architecture unresolved.
    $artifactFormat = if ($null -ne $SelectedArtifact.PSObject.Properties['Format']) { [string]$SelectedArtifact.Format } else { '' }
    $artifactFileName = if ($null -ne $SelectedArtifact.PSObject.Properties['FileName']) { [string]$SelectedArtifact.FileName } else { '' }
    $isPortableExecutable = $artifactFormat -eq 'exe' -or [System.IO.Path]::GetExtension($artifactFileName) -ieq '.exe'
    $outerArchitecture = if ($isPortableExecutable) { Get-WintainiumPortableExecutableArchitecture -Path $path } else { 'unknown' }
    $inspector = if ($isPortableExecutable) { 'native-pe-header' } else { 'native-static' }
    $reason = if ($isPortableExecutable) {
        'The file passed checksum verification, but native static inspection cannot establish the installed payload architecture. The executable header reports the outer file architecture only.'
    } else {
        'The file passed checksum verification, but no supported native static parser can establish the artifact payload architecture.'
    }
    [pscustomobject][ordered]@{
        IsSuccessful=$false
        Status='Unresolved'
        ReasonCode='ArchitectureRiskDecisionRequired'
        Reason=$reason
        PayloadArchitectures=@()
        ResolvedArchitecture=$null
        OuterArchitecture=$outerArchitecture
        Inspector=$inspector
    }
}
