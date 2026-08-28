function New-WintainiumUpdateDecisionInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Manifest,

        [Parameter(Mandatory)]
        [psobject]$InstalledState,

        [Parameter(Mandatory)]
        [psobject]$ProviderResult
    )

    if ($null -eq $Manifest) {
        throw [System.ArgumentNullException]::new('Manifest')
    }

    if ($null -eq $InstalledState) {
        throw [System.ArgumentNullException]::new('InstalledState')
    }

    if ($null -eq $ProviderResult) {
        throw [System.ArgumentNullException]::new('ProviderResult')
    }

    if (-not (Test-WintainiumInstalledApplicationState -State $InstalledState).IsValid) {
        throw [System.ArgumentException]::new('InstalledState must be a valid Wintainium installed application state.')
    }

    if (-not $Manifest.PSObject.Properties.Name.Contains('Id') -or [string]::IsNullOrWhiteSpace([string]$Manifest.Id)) {
        throw [System.ArgumentException]::new('Manifest must contain a non-empty Id.')
    }

    if ([string]$Manifest.Id -ne [string]$InstalledState.ApplicationId) {
        throw [System.ArgumentException]::new('Manifest.Id must match InstalledState.ApplicationId.')
    }

    [pscustomobject][ordered]@{
        Manifest = $Manifest
        InstalledState = $InstalledState
        ProviderResult = $ProviderResult
    }
}
