function Set-WintainiumInstalledApplicationState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StateRoot,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$State
    )

    $validation = Test-WintainiumInstalledApplicationState -State $State
    if (-not $validation.IsValid) {
        $message = ($validation.Errors | ForEach-Object { $_.Message }) -join ' '
        throw [System.ArgumentException]::new($message)
    }

    $root = [System.IO.Path]::GetFullPath($StateRoot.Trim())
    $statePath = Join-Path -Path $root -ChildPath 'installed-state.json'
    $tempPath = "$statePath.$([guid]::NewGuid().ToString('N')).tmp"

    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        [System.IO.Directory]::CreateDirectory($root) | Out-Null
    }

    $document = [ordered]@{ SchemaVersion = 1; States = @() }
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        try {
            $existing = Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($null -ne $existing.PSObject.Properties['SchemaVersion'] -and [int]$existing.SchemaVersion -ne 1) {
                throw [System.IO.InvalidDataException]::new('Unsupported installed-state schema version.')
            }
            $document.States = @($existing.States)
        }
        catch {
            if ($_.Exception -is [System.IO.InvalidDataException]) { throw }
            throw [System.IO.InvalidDataException]::new("Installed application state could not be read from '$statePath'.", $_.Exception)
        }
    }

    $replacement = [pscustomobject][ordered]@{
        ApplicationId = [string]$State.ApplicationId
        InstallationState = [string]$State.InstallationState
        Version = if ($null -eq $State.Version) { $null } else { [string]$State.Version }
        VersionSource = if ($null -eq $State.VersionSource) { $null } else { [string]$State.VersionSource }
        Architecture = [string]$State.Architecture
        Channel = [string]$State.Channel
        InstallationLocation = if ($null -eq $State.InstallationLocation) { $null } else { [string]$State.InstallationLocation }
    }

    $remaining = @($document.States | Where-Object {
        $null -eq $_.PSObject.Properties['ApplicationId'] -or
        -not [string]::Equals([string]$_.ApplicationId, [string]$State.ApplicationId, [System.StringComparison]::Ordinal)
    })
    $document.States = @($remaining + $replacement)
    $json = $document | ConvertTo-Json -Depth 10

    try {
        [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
        if ([System.IO.File]::Exists($statePath)) {
            [System.IO.File]::Replace($tempPath, $statePath, $null)
        }
        else {
            [System.IO.File]::Move($tempPath, $statePath)
        }
    }
    catch {
        if ([System.IO.File]::Exists($tempPath)) { [System.IO.File]::Delete($tempPath) }
        throw [System.IO.IOException]::new("Installed application state could not be written to '$statePath'.", $_.Exception)
    }

    $replacement
}
