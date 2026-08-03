function Test-WintaniumManifestSemantics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest
    )

    $errors = [System.Collections.Generic.List[object]]::new()
    $prohibitedKeyPattern = '(?i)(password|credential|secret|token|api[-_]?key|private[-_]?key)'

    function Find-ProhibitedManifestKeys {
        param(
            [Parameter(Mandatory)]
            [object]$Value,
            [Parameter(Mandatory)]
            [string]$Path
        )

        if ($Value -is [System.Collections.IDictionary]) {
            foreach ($key in $Value.Keys) {
                $childPath = "$Path.$key"
                if ($key -match $prohibitedKeyPattern) {
                    [pscustomobject]@{ Key = $key; Path = $childPath }
                }
                Find-ProhibitedManifestKeys -Value $Value[$key] -Path $childPath
            }
            return
        }

        if (($Value -is [System.Collections.IEnumerable]) -and ($Value -isnot [string])) {
            $index = 0
            foreach ($item in $Value) {
                Find-ProhibitedManifestKeys -Value $item -Path "$Path[$index]"
                $index++
            }
        }
    }

    foreach ($match in @(Find-ProhibitedManifestKeys -Value $Manifest -Path '$')) {
        $errors.Add([pscustomobject][ordered]@{
                Code = 'ManifestContainsProhibitedInformation'
                Path = $match.Path
                Message = "Manifest key '$($match.Key)' is not permitted."
            })
    }

    foreach ($urlField in @('homepage', 'documentation')) {
        if ($Manifest.ContainsKey($urlField) -and -not $Manifest[$urlField].StartsWith('https://', [System.StringComparison]::OrdinalIgnoreCase)) {
            $errors.Add([pscustomobject][ordered]@{
                    Code = 'ManifestUrlMustUseHttps'
                    Path = "`$$urlField"
                    Message = "Manifest field '$urlField' must use HTTPS."
                })
        }
    }

    $errors.ToArray()
}
