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

    $architecture = 'unknown'
    if ($null -ne $Evidence.PSObject.Properties['Architecture'] -and -not [string]::IsNullOrWhiteSpace([string]$Evidence.Architecture)) {
        $architecture = [string]$Evidence.Architecture
    }

    $channel = 'unknown'
    if ($null -ne $Evidence.PSObject.Properties['Channel'] -and -not [string]::IsNullOrWhiteSpace([string]$Evidence.Channel)) {
        $channel = [string]$Evidence.Channel
    }

    $version = ''
    if ($null -ne $Evidence.PSObject.Properties['Version'] -and $null -ne $Evidence.Version) {
        $version = [string]$Evidence.Version
    }

    $versionSource = ''
    if ($null -ne $Evidence.PSObject.Properties['VersionSource'] -and $null -ne $Evidence.VersionSource) {
        $versionSource = [string]$Evidence.VersionSource
    }

    $location = ''
    if ($null -ne $Evidence.PSObject.Properties['InstallationLocation'] -and $null -ne $Evidence.InstallationLocation) {
        $location = [string]$Evidence.InstallationLocation
    }

    New-WintainiumInstalledApplicationState `
        -ApplicationId $ApplicationId `
        -InstallationState ([string]$Evidence.InstallationState) `
        -Version $version `
        -VersionSource $versionSource `
        -Architecture $architecture `
        -Channel $channel `
        -InstallationLocation $location
}
