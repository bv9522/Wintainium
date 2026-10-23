function New-WintainiumVersionObservation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Version
    )

    $strategy = 'Opaque'
    $normalized = $Version
    $semantic = $null
    $systemVersion = $null
    $versionSuffix = $null

    $semanticPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$'
    if ($Version -match $semanticPattern) {
        $strategy = 'SemanticVersion'
        $semantic = [System.Management.Automation.SemanticVersion]::Parse($Version)
        $normalized = $semantic.ToString()
    }
    else {
        # Some publishers use a single trailing letter after a dotted numeric
        # version (for example, 11.50a). Keep this deliberately narrow: compare
        # the numeric portion first, then the suffix only when numeric portions
        # are equal. Do not infer ordering for arbitrary opaque vendor strings.
        $suffixMatch = [regex]::Match($Version, '^((?:0|[1-9]\d*)(?:\.(?:0|[1-9]\d*))+)([A-Za-z])$')
        if ($suffixMatch.Success) {
            $parsed = $null
            if ([System.Version]::TryParse($suffixMatch.Groups[1].Value, [ref]$parsed)) {
                $strategy = 'NumericVersionSuffix'
                $systemVersion = $parsed
                $versionSuffix = $suffixMatch.Groups[2].Value.ToLowerInvariant()
                $normalized = $parsed.ToString() + $versionSuffix
            }
        }

        if ($strategy -eq 'Opaque') {
            $parsed = $null
            if ([System.Version]::TryParse($Version, [ref]$parsed)) {
                $strategy = 'SystemVersion'
                $systemVersion = $parsed
                $normalized = $parsed.ToString()
            }
        }
    }

    [pscustomobject][ordered]@{
        Original = $Version
        Strategy = $strategy
        Normalized = $normalized
        SemanticVersion = $semantic
        SystemVersion = $systemVersion
        VersionSuffix = $versionSuffix
        IsComparable = $strategy -ne 'Opaque'
    }
}
