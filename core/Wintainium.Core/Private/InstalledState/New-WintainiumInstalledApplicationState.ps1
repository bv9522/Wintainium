function New-WintainiumInstalledApplicationState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ApplicationId,

        [Parameter(Mandatory)]
        [ValidateSet('Installed', 'NotInstalled', 'Unknown')]
        [string]$InstallationState,

        [AllowEmptyString()]
        [string]$Version,

        [AllowEmptyString()]
        [string]$VersionSource,

        [ValidateSet('x86', 'x64', 'arm64', 'neutral', 'unknown')]
        [string]$Architecture = 'unknown',

        [ValidateSet('stable', 'prerelease', 'unknown')]
        [string]$Channel = 'unknown',

        [AllowEmptyString()]
        [string]$InstallationLocation
    )

    $state = [pscustomobject][ordered]@{
        ApplicationId = $ApplicationId
        InstallationState = $InstallationState
        Version = $Version
        VersionSource = $VersionSource
        Architecture = $Architecture
        Channel = $Channel
        InstallationLocation = $InstallationLocation
    }

    $validation = Test-WintainiumInstalledApplicationState -State $state
    if (-not $validation.IsValid) {
        $message = ($validation.Errors | ForEach-Object { $_.Message }) -join ' '
        throw [System.ArgumentException]::new($message)
    }

    return $state
}
