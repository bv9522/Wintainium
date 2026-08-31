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

    $semanticPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$'
    if ($Version -match $semanticPattern) {
        $strategy = 'SemanticVersion'
        $semantic = [System.Management.Automation.SemanticVersion]::Parse($Version)
        $normalized = $semantic.ToString()
    }
    else {
        $parsed = $null
        if ([System.Version]::TryParse($Version, [ref]$parsed)) {
            $strategy = 'SystemVersion'
            $systemVersion = $parsed
            $normalized = $parsed.ToString()
        }
    }

    [pscustomobject][ordered]@{
        Original = $Version
        Strategy = $strategy
        Normalized = $normalized
        SemanticVersion = $semantic
        SystemVersion = $systemVersion
        IsComparable = $strategy -ne 'Opaque'
    }
}
