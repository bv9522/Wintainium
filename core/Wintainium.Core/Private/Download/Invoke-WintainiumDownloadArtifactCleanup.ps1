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
        [string]$Outcome
    )

    if ($null -eq $DownloadResult -or -not $DownloadResult.PSObject.Properties['DestinationPath']) {
        return [pscustomobject][ordered]@{
            IsSuccessful = $true
            Status = 'NoArtifact'
            Outcome = $Outcome
            Removed = $false
            Retained = $false
            DestinationPath = $null
            ArtifactDirectory = $null
            ReasonCode = 'NoDownloadArtifact'
            Error = $null
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$DownloadResult.DestinationPath)) {
        return [pscustomobject][ordered]@{
            IsSuccessful = $true
            Status = 'NoArtifact'
            Outcome = $Outcome
            Removed = $false
            Retained = $false
            DestinationPath = $null
            ArtifactDirectory = $null
            ReasonCode = 'NoDownloadArtifactPath'
            Error = $null
        }
    }

    $destination = [System.IO.Path]::GetFullPath([string]$DownloadResult.DestinationPath)
    $root = [System.IO.Path]::GetFullPath($DownloadRoot)
    $rootWithSeparator = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if (-not $destination.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject][ordered]@{
            IsSuccessful = $true
            Status = 'NotManaged'
            Outcome = $Outcome
            Removed = $false
            Retained = $false
            DestinationPath = $destination
            ArtifactDirectory = $null
            ReasonCode = 'ArtifactOutsideDownloadRoot'
            Error = $null
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
                # Retention itself remains authoritative. Metadata is diagnostic enrichment
                # and must never delete or invalidate the retained artifact.
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
            # The artifact itself is gone. A non-empty or locked operation directory is
            # harmless and is intentionally not allowed to turn a successful update into
            # a failed update.
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
        DirectoryRemoved = $directoryRemoved
        ReasonCode = 'ArtifactRemovedAfterSuccessfulUpdate'
        Error = $null
    }
}
