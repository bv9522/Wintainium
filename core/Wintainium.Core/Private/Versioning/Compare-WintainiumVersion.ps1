function Compare-WintainiumVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Left,

        [Parameter(Mandatory)]
        [psobject]$Right
    )

    if ($null -eq $Left -or $null -eq $Right) {
        throw [System.ArgumentNullException]::new('Version observation')
    }

    if (-not $Left.PSObject.Properties.Name.Contains('Strategy') -or
        -not $Right.PSObject.Properties.Name.Contains('Strategy')) {
        throw [System.ArgumentException]::new('Both inputs must be Wintainium version observations.')
    }

    if ($Left.Strategy -ne $Right.Strategy -or $Left.Strategy -eq 'Opaque') {
        $comparison = 'Unknown'
    }
    elseif ($Left.Strategy -eq 'SemanticVersion') {
        $value = $Left.SemanticVersion.CompareTo($Right.SemanticVersion)
        $comparison = if ($value -lt 0) { 'Less' } elseif ($value -gt 0) { 'Greater' } else { 'Equal' }
    }
    elseif ($Left.Strategy -eq 'SystemVersion') {
        $value = $Left.SystemVersion.CompareTo($Right.SystemVersion)
        $comparison = if ($value -lt 0) { 'Less' } elseif ($value -gt 0) { 'Greater' } else { 'Equal' }
    }
    else {
        $comparison = 'Unknown'
    }

    [pscustomobject][ordered]@{
        Comparison = $comparison
        Strategy = if ($Left.Strategy -eq $Right.Strategy) { $Left.Strategy } else { 'Incompatible' }
        Left = $Left
        Right = $Right
        IsDeterministic = $comparison -ne 'Unknown'
    }
}
