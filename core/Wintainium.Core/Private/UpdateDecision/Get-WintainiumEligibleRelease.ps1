function Get-WintainiumEligibleRelease {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [psobject[]]$Releases,
        [Parameter(Mandatory)] [psobject]$Manifest,
        [Parameter(Mandatory)] [psobject]$InstalledState
    )

    $observations = foreach ($release in $Releases) {
        Test-WintainiumReleaseEligibility -Release $release -Manifest $Manifest -InstalledState $InstalledState
    }

    [pscustomobject][ordered]@{
        EligibleReleases = @($observations | Where-Object Eligible | ForEach-Object Release)
        Observations = @($observations)
        IsDeterministic = $true
    }
}
