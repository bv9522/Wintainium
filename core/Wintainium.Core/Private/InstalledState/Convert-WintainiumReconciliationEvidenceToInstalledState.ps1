function Convert-WintainiumReconciliationEvidenceToInstalledState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationId,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$Evidence
    )

    if ([string]::IsNullOrWhiteSpace($ApplicationId)) {
        throw [System.ArgumentException]::new('ApplicationId must not be empty or whitespace.')
    }

    foreach ($propertyName in @('ApplicationId', 'InstallationState', 'EvidenceSource')) {
        if ($null -eq $Evidence.PSObject.Properties[$propertyName]) {
            throw [System.ArgumentException]::new("Reconciliation evidence is missing required property '$propertyName'.")
        }
    }

    if ([string]$Evidence.ApplicationId -ne $ApplicationId) {
        throw [System.ArgumentException]::new('Reconciliation evidence ApplicationId does not match the requested application.')
    }

    $architecture = if ($null -ne $Evidence.PSObject.Properties['Architecture'] -and -not [string]::IsNullOrWhiteSpace([string]$Evidence.Architecture)) { [string]$Evidence.Architecture } else { 'unknown' }
    $channel = if ($null -ne $Evidence.PSObject.Properties['Channel'] -and -not [string]::IsNullOrWhiteSpace([string]$Evidence.Channel)) { [string]$Evidence.Channel } else { 'unknown' }
    $version = if ($null -ne $Evidence.PSObject.Properties['Version']) { $Evidence.Version } else { $null }
    $versionSource = if ($null -ne $Evidence.PSObject.Properties['VersionSource']) { $Evidence.VersionSource } else { $null }
    $location = if ($null -ne $Evidence.PSObject.Properties['InstallationLocation']) { $Evidence.InstallationLocation } else { $null }

    New-WintainiumInstalledApplicationState `
        -ApplicationId $ApplicationId `
        -InstallationState ([string]$Evidence.InstallationState) `
        -Version (if ($null -eq $version) { '' } else { [string]$version }) `
        -VersionSource (if ($null -eq $versionSource) { '' } else { [string]$versionSource }) `
        -Architecture $architecture `
        -Channel $channel `
        -InstallationLocation (if ($null -eq $location) { '' } else { [string]$location })
}
