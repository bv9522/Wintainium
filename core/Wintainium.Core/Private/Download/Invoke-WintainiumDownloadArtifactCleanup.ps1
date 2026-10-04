function Invoke-WintainiumDownloadArtifactCleanup {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$DownloadResult,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DownloadRoot,

        [Parameter(Mandatory)]
        [ValidateSet('Completed','Failed','Cancelled')]
        [string]$Outcome,

        [ValidateRange(1,365)]
        [int]$RetentionDays = 7,

        [ValidateRange(1,100)]
        [int]$MaxRetainedOperations = 20
    )

    $emptyResult = {
        param([string]$Status,[string]$ReasonCode,[bool]$Removed,[bool]$Retained,[string]$DestinationPath,[string]$ArtifactDirectory)
        [pscustomobject][ordered]@{
            IsSuccessful = $true
            Status = $Status
            Outcome = $Outcome
            Removed = $Removed
            Retained = $Retained
            DestinationPath = $DestinationPath
            ArtifactDirectory = $ArtifactDirectory
            MetadataPath = $null
            MetadataWritten = $false
            DirectoryRemoved = $false
            PurgedOperations = @()
            PurgedLegacyArtifacts = @()
            ReasonCode = $ReasonCode
            Error = $null
        }
    }

    if ($null -eq $DownloadResult -or -not $DownloadResult.PSObject.Properties['DestinationPath']) {
        return & $emptyResult 'NoArtifact' 'NoDownloadArtifact' $false $false $null $null
    }

    if ([string]::IsNullOrWhiteSpace([string]$DownloadResult.DestinationPath)) {
        return & $emptyResult 'NoArtifact' 'NoDownloadArtifactPath' $false $false $null $null
    }

    $destination = [System.IO.Path]::GetFullPath([string]$DownloadResult.DestinationPath)
    $root = [System.IO.Path]::GetFullPath($DownloadRoot)
    $rootWithSeparator = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if (-not $destination.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        return & $emptyResult 'NotManaged' 'ArtifactOutsideDownloadRoot' $false $false $destination $null
    }

    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $root -Force -ErrorAction Stop | Out-Null
        }
        catch {
            return [pscustomobject][ordered]@{
                IsSuccessful = $false
                Status = 'CleanupMaintenanceFailed'
                Outcome = $Outcome
                Removed = $false
                Retained = $false
                DestinationPath = $destination
                ArtifactDirectory = $null
                MetadataPath = $null
                MetadataWritten = $false
                DirectoryRemoved = $false
                PurgedOperations = @()
                PurgedLegacyArtifacts = @()
                ReasonCode = 'DownloadRootUnavailable'
                Error = [pscustomobject][ordered]@{ Code='DownloadRootUnavailable'; Message=$_.Exception.Message }
            }
        }
    }

    $operationsRoot = Join-Path $root 'operations'
    # Reserve one retention slot for the current failed/cancelled operation so
    # the bound remains true immediately after this cleanup pass.
    $operationRetentionLimit = if ($Outcome -ne 'Completed') { [Math]::Max(1, $MaxRetainedOperations - 1) } else { $MaxRetainedOperations }
    $purgedOperations = [System.Collections.Generic.List[string]]::new()
    $purgedLegacyArtifacts = [System.Collections.Generic.List[string]]::new()

    # The root is Core-owned download storage. Files directly under the root are
    # artifacts from the legacy pre-operation-directory layout. Only recognized
    # downloadable artifact extensions are removed; subdirectories are untouched.
    $legacyExtensions = @('.exe','.msi','.msix','.zip','.7z','.cab')
    try {
        foreach ($legacyArtifact in @(Get-ChildItem -LiteralPath $root -File -Force -ErrorAction Stop)) {
            if ($legacyExtensions -contains $legacyArtifact.Extension.ToLowerInvariant()) {
                try {
                    Remove-Item -LiteralPath $legacyArtifact.FullName -Force -ErrorAction Stop
                    $purgedLegacyArtifacts.Add($legacyArtifact.FullName)
                }
                catch {
                    # Legacy cleanup is maintenance only. A locked artifact is left
                    # in place and never changes the operation outcome.
                }
            }
        }
    }
    catch {
        # Maintenance failure is intentionally non-authoritative.
    }

    # Failed/cancelled artifacts are useful for troubleshooting, but retention is
    # temporary and bounded so repeated failures cannot consume the user's disk.
    if (Test-Path -LiteralPath $operationsRoot -PathType Container) {
        $nowUtc = [DateTime]::UtcNow
        $cutoffUtc = $nowUtc.AddDays(-$RetentionDays)
        $operationDirectories = @()
        try {
            $operationDirectories = @(Get-ChildItem -LiteralPath $operationsRoot -Directory -Force -ErrorAction Stop)
        }
        catch {
            $operationDirectories = @()
        }

        $retainedOperations = foreach ($operationDirectory in $operationDirectories) {
            $metadataPath = Join-Path $operationDirectory.FullName '.wintainium-artifact.json'
            $retainedAtUtc = $operationDirectory.LastWriteTimeUtc
            if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
                try {
                    $metadata = Get-Content -LiteralPath $metadataPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                    if ($metadata.RetainedAtUtc) {
                        $parsed = [DateTime]::MinValue
                        if ([DateTime]::TryParse([string]$metadata.RetainedAtUtc, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) {
                            $retainedAtUtc = $parsed.ToUniversalTime()
                        }
                    }
                }
                catch {
                    # Fall back to directory timestamp when diagnostic metadata is
                    # missing or malformed.
                }
            }

            [pscustomobject]@{
                Directory = $operationDirectory
                RetainedAtUtc = $retainedAtUtc
            }
        }

        foreach ($retained in @($retainedOperations | Where-Object { $_.RetainedAtUtc -lt $cutoffUtc })) {
            try {
                Remove-Item -LiteralPath $retained.Directory.FullName -Recurse -Force -ErrorAction Stop
                $purgedOperations.Add($retained.Directory.FullName)
            }
            catch {
                # A locked or otherwise unavailable operation directory is retained
                # until a later maintenance pass.
            }
        }

        $remaining = @(
            $retainedOperations |
                Where-Object { $purgedOperations -notcontains $_.Directory.FullName } |
                Sort-Object RetainedAtUtc -Descending
        )
        if ($remaining.Count -gt $operationRetentionLimit) {
            foreach ($retained in @($remaining | Select-Object -Skip $operationRetentionLimit)) {
                try {
                    Remove-Item -LiteralPath $retained.Directory.FullName -Recurse -Force -ErrorAction Stop
                    $purgedOperations.Add($retained.Directory.FullName)
                }
                catch {
                    # Retention bounds are best-effort maintenance and do not alter
                    # the authoritative operation result.
                }
            }
        }
    }

    $artifactDirectory = if ($DownloadResult.PSObject.Properties['ArtifactDirectory'] -and -not [string]::IsNullOrWhiteSpace([string]$DownloadResult.ArtifactDirectory)) {
        [System.IO.Path]::GetFullPath([string]$DownloadResult.ArtifactDirectory)
    } else {
        [System.IO.Path]::GetDirectoryName($destination)
    }

    if (-not [string]::IsNullOrWhiteSpace($artifactDirectory)) {
        $artifactDirectoryWithSeparator = $artifactDirectory.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        if ($artifactDirectory -ne $root -and -not $artifactDirectory.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
            $artifactDirectory = [System.IO.Path]::GetDirectoryName($destination)
        }
    }

    if ($Outcome -ne 'Completed') {
        $artifactExists = Test-Path -LiteralPath $destination
        $metadataPath = $null
        $metadataWritten = $false

        if ($artifactExists -and $artifactDirectory -ne $root -and (Test-Path -LiteralPath $artifactDirectory)) {
            $metadataPath = Join-Path $artifactDirectory '.wintainium-artifact.json'
            try {
                [pscustomobject][ordered]@{
                    SchemaVersion = '1.0'
                    OperationId = if ($DownloadResult.PSObject.Properties['OperationId']) { [string]$DownloadResult.OperationId } else { $null }
                    Outcome = $Outcome
                    Uri = if ($DownloadResult.PSObject.Properties['Uri']) { [string]$DownloadResult.Uri } else { $null }
                    FileName = if ($DownloadResult.PSObject.Properties['FileName']) { [string]$DownloadResult.FileName } else { $null }
                    DestinationPath = $destination
                    FailureKind = if ($DownloadResult.PSObject.Properties['FailureKind']) { [string]$DownloadResult.FailureKind } else { $null }
                    ErrorMessage = if ($DownloadResult.PSObject.Properties['ErrorMessage']) { [string]$DownloadResult.ErrorMessage } else { $null }
                    RetainedAtUtc = [DateTime]::UtcNow.ToString('o')
                } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metadataPath -Encoding UTF8
                $metadataWritten = $true
            }
            catch {
                # Retention itself remains authoritative. Metadata is diagnostic
                # enrichment and must never delete or invalidate the artifact.
            }
        }

        return [pscustomobject][ordered]@{
            IsSuccessful = $true
            Status = if ($artifactExists) { 'Retained' } else { 'NoArtifact' }
            Outcome = $Outcome
            Removed = $false
            Retained = $artifactExists
            DestinationPath = $destination
            ArtifactDirectory = $artifactDirectory
            MetadataPath = $metadataPath
            MetadataWritten = $metadataWritten
            DirectoryRemoved = $false
            PurgedOperations = @($purgedOperations)
            PurgedLegacyArtifacts = @($purgedLegacyArtifacts)
            ReasonCode = if ($artifactExists) { 'ArtifactRetainedForTroubleshooting' } else { 'NoCompletedArtifactToRetain' }
            Error = $null
        }
    }

    if (-not (Test-Path -LiteralPath $destination)) {
        return [pscustomobject][ordered]@{
            IsSuccessful = $true
            Status = 'AlreadyAbsent'
            Outcome = $Outcome
            Removed = $false
            Retained = $false
            DestinationPath = $destination
            ArtifactDirectory = $artifactDirectory
            MetadataPath = $null
            MetadataWritten = $false
            DirectoryRemoved = $false
            PurgedOperations = @($purgedOperations)
            PurgedLegacyArtifacts = @($purgedLegacyArtifacts)
            ReasonCode = 'ArtifactAlreadyAbsent'
            Error = $null
        }
    }

    try {
        Remove-Item -LiteralPath $destination -Force -ErrorAction Stop
    }
    catch {
        return [pscustomobject][ordered]@{
            IsSuccessful = $false
            Status = 'CleanupFailed'
            Outcome = $Outcome
            Removed = $false
            Retained = $true
            DestinationPath = $destination
            ArtifactDirectory = $artifactDirectory
            MetadataPath = $null
            MetadataWritten = $false
            DirectoryRemoved = $false
            PurgedOperations = @($purgedOperations)
            PurgedLegacyArtifacts = @($purgedLegacyArtifacts)
            ReasonCode = 'ArtifactCleanupFailed'
            Error = [pscustomobject][ordered]@{
                Code = 'ArtifactCleanupFailed'
                Message = $_.Exception.Message
            }
        }
    }

    $directoryRemoved = $false
    if ($artifactDirectory -ne $root -and (Test-Path -LiteralPath $artifactDirectory)) {
        try {
            if (@(Get-ChildItem -LiteralPath $artifactDirectory -Force -ErrorAction Stop).Count -eq 0) {
                Remove-Item -LiteralPath $artifactDirectory -Force -ErrorAction Stop
                $directoryRemoved = $true
            }
        }
        catch {
            # The artifact itself is gone. A non-empty or locked operation directory
            # is harmless and is intentionally not allowed to turn a successful
            # operation into a failed operation.
        }
    }

    [pscustomobject][ordered]@{
        IsSuccessful = $true
        Status = 'Removed'
        Outcome = $Outcome
        Removed = $true
        Retained = $false
        DestinationPath = $destination
        ArtifactDirectory = $artifactDirectory
        MetadataPath = $null
        MetadataWritten = $false
        DirectoryRemoved = $directoryRemoved
        PurgedOperations = @($purgedOperations)
        PurgedLegacyArtifacts = @($purgedLegacyArtifacts)
        ReasonCode = 'ArtifactRemovedAfterSuccessfulUpdate'
        Error = $null
    }
}