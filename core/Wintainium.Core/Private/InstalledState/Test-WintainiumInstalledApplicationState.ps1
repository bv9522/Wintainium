function Test-WintainiumInstalledApplicationState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$State
    )

    $errors = [System.Collections.Generic.List[object]]::new()

    $requiredProperties = @(
        'ApplicationId',
        'InstallationState',
        'Version',
        'VersionSource',
        'Architecture',
        'Channel',
        'InstallationLocation'
    )

    foreach ($property in $requiredProperties) {
        if ($null -eq $State.PSObject.Properties[$property]) {
            $errors.Add([pscustomobject]@{
                Code = 'InstalledStatePropertyMissing'
                Property = $property
                Message = "Installed application state is missing required property '$property'."
            })
        }
    }

    if ($null -eq $State.PSObject.Properties['ApplicationId'] -or
        [string]::IsNullOrWhiteSpace([string]$State.ApplicationId)) {
        $errors.Add([pscustomobject]@{
            Code = 'InstalledStateApplicationIdInvalid'
            Property = 'ApplicationId'
            Message = 'ApplicationId must be a non-empty value.'
        })
    }

    $validInstallationStates = @('Installed', 'NotInstalled', 'Unknown')
    if ($null -ne $State.PSObject.Properties['InstallationState'] -and
        [string]$State.InstallationState -notin $validInstallationStates) {
        $errors.Add([pscustomobject]@{
            Code = 'InstalledStateInstallationStateInvalid'
            Property = 'InstallationState'
            Message = 'InstallationState must be Installed, NotInstalled, or Unknown.'
        })
    }

    $validArchitectures = @('x86', 'x64', 'arm64', 'neutral', 'unknown')
    if ($null -ne $State.PSObject.Properties['Architecture'] -and
        [string]$State.Architecture -notin $validArchitectures) {
        $errors.Add([pscustomobject]@{
            Code = 'InstalledStateArchitectureInvalid'
            Property = 'Architecture'
            Message = 'Architecture must be x86, x64, arm64, neutral, or unknown.'
        })
    }

    $validChannels = @('stable', 'prerelease', 'unknown')
    if ($null -ne $State.PSObject.Properties['Channel'] -and
        [string]$State.Channel -notin $validChannels) {
        $errors.Add([pscustomobject]@{
            Code = 'InstalledStateChannelInvalid'
            Property = 'Channel'
            Message = 'Channel must be stable, prerelease, or unknown.'
        })
    }

    if ($null -ne $State.PSObject.Properties['InstallationState'] -and
        [string]$State.InstallationState -eq 'NotInstalled' -and
        $null -ne $State.PSObject.Properties['Version'] -and
        -not [string]::IsNullOrWhiteSpace([string]$State.Version)) {
        $errors.Add([pscustomobject]@{
            Code = 'InstalledStateVersionPresentWhenNotInstalled'
            Property = 'Version'
            Message = 'Version must be absent or empty when InstallationState is NotInstalled.'
        })
    }

    [pscustomobject][ordered]@{
        IsValid = $errors.Count -eq 0
        Errors = $errors.ToArray()
    }
}
