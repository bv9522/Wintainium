function Get-WintainiumInstalledApplicationState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StateRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationId
    )

    $statePath = Join-Path -Path ([System.IO.Path]::GetFullPath($StateRoot.Trim())) -ChildPath 'installed-state.json'
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        return New-WintainiumInstalledApplicationState -ApplicationId $ApplicationId -InstallationState Unknown
    }

    try {
        $document = Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw [System.IO.InvalidDataException]::new("Installed application state could not be read from '$statePath'.", $_.Exception)
    }

    $record = @($document.States | Where-Object {
        $null -ne $_.PSObject.Properties['ApplicationId'] -and
        [string]::Equals([string]$_.ApplicationId, $ApplicationId, [System.StringComparison]::Ordinal)
    }) | Select-Object -First 1

    if ($null -eq $record) {
        return New-WintainiumInstalledApplicationState -ApplicationId $ApplicationId -InstallationState Unknown
    }

    $validation = Test-WintainiumInstalledApplicationState -State $record
    if (-not $validation.IsValid) {
        throw [System.IO.InvalidDataException]::new("Persisted installed application state for '$ApplicationId' is invalid.")
    }

    [pscustomobject][ordered]@{
        ApplicationId = [string]$record.ApplicationId
        InstallationState = [string]$record.InstallationState
        Version = if ($null -eq $record.Version) { $null } else { [string]$record.Version }
        VersionSource = if ($null -eq $record.VersionSource) { $null } else { [string]$record.VersionSource }
        Architecture = [string]$record.Architecture
        Channel = [string]$record.Channel
        InstallationLocation = if ($null -eq $record.InstallationLocation) { $null } else { [string]$record.InstallationLocation }
    }
}
