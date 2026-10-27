function Test-WintainiumInstallerArchitectureInspectionAvailable {
    [CmdletBinding()]
    param()
    return $null -ne (Get-Command innoextract.exe, innoextract -ErrorAction SilentlyContinue | Select-Object -First 1)
}

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

function Invoke-WintainiumInnoExtract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ToolPath,
        [Parameter(Mandatory)][string]$InstallerPath,
        [Parameter(Mandatory)][string]$OutputDirectory,
        [ValidateRange(1, 600)][int]$TimeoutSeconds = 60
    )

    $stdoutPath = Join-Path $OutputDirectory 'innoextract.stdout.txt'
    $stderrPath = Join-Path $OutputDirectory 'innoextract.stderr.txt'
    $quotedOutput = '"' + $OutputDirectory.Replace('"', '\"') + '"'
    $quotedInstaller = '"' + $InstallerPath.Replace('"', '\"') + '"'
    $arguments = "--extract --collisions=rename-all --output-dir $quotedOutput $quotedInstaller"
    $process = $null
    try {
        $process = Start-Process -FilePath $ToolPath -ArgumentList $arguments -PassThru -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $process.Kill() } catch {}
            return [pscustomobject]@{ IsSuccessful=$false; ReasonCode='ArchitectureInspectionTimedOut'; ErrorMessage='Static extraction exceeded its time limit.' }
        }
        if ($process.ExitCode -ne 0) {
            return [pscustomobject]@{ IsSuccessful=$false; ReasonCode='UnsupportedInstallerFormat'; ErrorMessage='The static extractor could not parse this installer format.'; ExitCode=$process.ExitCode }
        }
        return [pscustomobject]@{ IsSuccessful=$true; ReasonCode='StaticExtractionCompleted'; ErrorMessage=$null; ExitCode=$process.ExitCode }
    }
    catch {
        return [pscustomobject]@{ IsSuccessful=$false; ReasonCode='StaticExtractionFailed'; ErrorMessage='The static extractor could not be started or completed.' }
    }
    finally { if ($null -ne $process) { $process.Dispose() } }
}

function Resolve-WintainiumInstallerPayloadArchitecture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$DownloadResult,
        [Parameter(Mandatory)][psobject]$SelectedArtifact,
        [Parameter(Mandatory)][psobject]$VerificationResult,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$MachineArchitecture,
        [string]$InnoExtractPath
    )

    $failure = {
        param([string]$ReasonCode, [string]$Reason, [object[]]$PayloadArchitectures = @())
        [pscustomobject][ordered]@{ IsSuccessful=$false; Status='Unresolved'; ReasonCode=$ReasonCode; Reason=$Reason; PayloadArchitectures=@($PayloadArchitectures); ResolvedArchitecture=$null; Inspector='innoextract' }
    }

    if ($null -eq $DownloadResult -or [string]$DownloadResult.Status -ne 'Downloaded' -or
        [string]$VerificationResult.Status -ne 'Verified' -or [string]$VerificationResult.Algorithm -ne 'SHA256') {
        return & $failure 'VerifiedArtifactRequired' 'Inspection requires a completed download verified by a matching SHA256 checksum.'
    }
    $path = [string]$DownloadResult.DestinationPath
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return & $failure 'ArtifactPathMissing' 'The verified installer file is unavailable.'
    }
    if ([System.IO.Path]::GetExtension([string]$SelectedArtifact.FileName) -ine '.exe' -or [string]$SelectedArtifact.Architecture -ine 'unknown') {
        return & $failure 'InspectionNotApplicable' 'Inspection applies only to executable artifacts with unknown architecture.'
    }
    if ([string]::IsNullOrWhiteSpace($InnoExtractPath)) {
        $command = Get-Command innoextract.exe, innoextract -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $command) { return & $failure 'ArchitectureInspectorUnavailable' 'No supported static installer inspector is available.' }
        $InnoExtractPath = [string]$command.Source
    }
    if ((Get-Item -LiteralPath $path).Length -gt 536870912) {
        return & $failure 'InstallerTooLargeForInspection' 'The installer exceeds the static-inspection size limit.'
    }

    $inspectionRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('Wintainium-ArchitectureInspection-' + [guid]::NewGuid().ToString('N'))
    $outputDirectory = Join-Path $inspectionRoot 'payload'
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    try {
        $extraction = Invoke-WintainiumInnoExtract -ToolPath $InnoExtractPath -InstallerPath $path -OutputDirectory $outputDirectory
        if ($null -eq $extraction -or -not [bool]$extraction.IsSuccessful) {
            $code = if ($null -ne $extraction -and $extraction.PSObject.Properties['ReasonCode']) { [string]$extraction.ReasonCode } else { 'StaticExtractionFailed' }
            $reason = if ($null -ne $extraction -and $extraction.PSObject.Properties['ErrorMessage']) { [string]$extraction.ErrorMessage } else { 'The installer could not be statically inspected.' }
            return & $failure $code $reason
        }

        $files = @(Get-ChildItem -LiteralPath $outputDirectory -File -Recurse -ErrorAction Stop)
        if ($files.Count -gt 20000 -or (($files | Measure-Object -Property Length -Sum).Sum -gt 2147483648)) {
            return & $failure 'ExtractedPayloadLimitExceeded' 'The extracted payload exceeds static-inspection safety limits.'
        }
        $appRoot = Join-Path $outputDirectory 'app'
        if (-not (Test-Path -LiteralPath $appRoot -PathType Container)) { $appRoot = $outputDirectory }
        $executables = @(Get-ChildItem -LiteralPath $appRoot -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)\.exe(?:\$\d+)?$' })
        if ($executables.Count -eq 0) { return & $failure 'ApplicationPayloadNotFound' 'No top-level application executable was found in the extracted payload.' }

        $groups = @{}
        foreach ($exe in $executables) {
            $name = $exe.Name -replace '\$\d+$', ''
            if (-not $groups.ContainsKey($name)) { $groups[$name] = [System.Collections.Generic.List[object]]::new() }
            $groups[$name].Add((Get-WintainiumPortableExecutableArchitecture -Path $exe.FullName))
        }
        $multiArch = @($groups.Keys | Where-Object { @($groups[$_] | Where-Object { $_ -ne 'unknown' } | Select-Object -Unique).Count -gt 1 })
        if ($multiArch.Count -eq 1) {
            $payloadArchitectures = @($groups[$multiArch[0]] | Where-Object { $_ -ne 'unknown' } | Select-Object -Unique)
        } elseif ($groups.Count -eq 1) {
            $payloadArchitectures = @($groups.Values | Select-Object -First 1 | ForEach-Object { $_ } | Where-Object { $_ -ne 'unknown' } | Select-Object -Unique)
        } else {
            return & $failure 'ApplicationPayloadAmbiguous' 'Multiple application executables were found without an unambiguous architecture relationship.'
        }
        if ($payloadArchitectures.Count -eq 0) { return & $failure 'PayloadArchitectureUnknown' 'The application executable architecture could not be established.' }
        $target = $MachineArchitecture.Trim().ToLowerInvariant()
        if ($target -notin $payloadArchitectures) { return & $failure 'ArchitectureIncompatible' 'The installer does not contain an application executable for the target architecture.' $payloadArchitectures }

        [pscustomobject][ordered]@{
            IsSuccessful=$true
            Status='Resolved'
            ReasonCode=if ($payloadArchitectures.Count -gt 1) { 'DualArchitecturePayloadConfirmed' } else { 'SingleArchitecturePayloadConfirmed' }
            Reason='Static inspection established the application executable payload architecture.'
            PayloadArchitectures=@($payloadArchitectures)
            ResolvedArchitecture=$target
            Inspector='innoextract'
        }
    }
    catch { return & $failure 'ArchitectureInspectionFailed' 'Static inspection failed; the artifact remains architecture-unknown.' }
    finally {
        try { if (Test-Path -LiteralPath $inspectionRoot) { Remove-Item -LiteralPath $inspectionRoot -Recurse -Force -ErrorAction SilentlyContinue } } catch {}
    }
}
