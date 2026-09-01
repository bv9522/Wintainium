function New-WintainiumDownloadRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UpdateDecision
    )

    if ($null -eq $UpdateDecision) {
        throw [System.ArgumentNullException]::new('UpdateDecision')
    }

    foreach ($requiredProperty in @('Status', 'IsUpdateAvailable', 'SelectedRelease', 'SelectedArtifact')) {
        if (-not $UpdateDecision.PSObject.Properties[$requiredProperty]) {
            throw [System.ArgumentException]::new("UpdateDecision is missing required property '$requiredProperty'.")
        }
    }

    if ([string]$UpdateDecision.Status -ne 'UpdateAvailable' -or -not [bool]$UpdateDecision.IsUpdateAvailable) {
        throw [System.ArgumentException]::new('Only an UpdateAvailable decision can be converted into a download request.')
    }

    if ($null -eq $UpdateDecision.SelectedRelease) {
        throw [System.ArgumentException]::new('An UpdateAvailable decision must contain a selected release.')
    }

    if ($null -eq $UpdateDecision.SelectedArtifact) {
        throw [System.ArgumentException]::new('An UpdateAvailable decision must contain a selected artifact.')
    }

    [pscustomobject][ordered]@{
        OperationId = [guid]::NewGuid().Guid
        UpdateDecision = $UpdateDecision
        SelectedRelease = $UpdateDecision.SelectedRelease
        SelectedArtifact = $UpdateDecision.SelectedArtifact
    }
}
