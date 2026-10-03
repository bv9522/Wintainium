function New-WintainiumDownloadRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$UpdateDecision,
        [string]$OperationId
    )

    if ($null -eq $UpdateDecision) { throw [System.ArgumentNullException]::new('UpdateDecision') }
    foreach ($requiredProperty in @('Status', 'SelectedRelease', 'SelectedArtifact')) {
        if (-not $UpdateDecision.PSObject.Properties[$requiredProperty]) { throw [System.ArgumentException]::new("Lifecycle decision is missing required property '$requiredProperty'.") }
    }

    $isUpdateAvailable = $UpdateDecision.PSObject.Properties['IsUpdateAvailable'] -and [bool]$UpdateDecision.IsUpdateAvailable
    $isInstallAvailable = $UpdateDecision.PSObject.Properties['IsInstallAvailable'] -and [bool]$UpdateDecision.IsInstallAvailable
    $isDownloadableDecision = ([string]$UpdateDecision.Status -eq 'UpdateAvailable' -and $isUpdateAvailable) -or
        ([string]$UpdateDecision.Status -eq 'InstallAvailable' -and $isInstallAvailable)

    if (-not $isDownloadableDecision) {
        throw [System.ArgumentException]::new('Only an UpdateAvailable or InstallAvailable decision can be converted into a download request.')
    }
    if ($null -eq $UpdateDecision.SelectedRelease) { throw [System.ArgumentException]::new('An UpdateAvailable decision must contain a selected release.') }
    if ($null -eq $UpdateDecision.SelectedArtifact) { throw [System.ArgumentException]::new('An UpdateAvailable decision must contain a selected artifact.') }

    $resolvedOperationId = if ([string]::IsNullOrWhiteSpace($OperationId)) {
        [guid]::NewGuid().ToString()
    } else {
        $parsed = [guid]::Empty
        if (-not [guid]::TryParse($OperationId, [ref]$parsed)) { throw [System.ArgumentException]::new('OperationId must be a valid GUID.') }
        $parsed.ToString()
    }

    [pscustomobject][ordered]@{
        OperationId = $resolvedOperationId
        UpdateDecision = $UpdateDecision
        Decision = $UpdateDecision
        SelectedRelease = $UpdateDecision.SelectedRelease
        SelectedArtifact = $UpdateDecision.SelectedArtifact
    }
}
