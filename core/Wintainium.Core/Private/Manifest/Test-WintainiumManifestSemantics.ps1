function Test-WintainiumManifestSemantics {
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

    if ($Manifest.ContainsKey('source') -and $Manifest['source'] -is [System.Collections.IDictionary] -and $Manifest['source'].Contains('context')) {
        $context = $Manifest['source']['context']
        $contextState = [pscustomobject]@{ NodeCount = 0; Invalid = $false; Reason = $null }

        function Test-ManifestSourceContextValue {
            param([AllowNull()][object]$Value, [int]$Depth, [object]$State)

            $State.NodeCount++
            if ($Depth -gt 8 -or $State.NodeCount -gt 256) {
                $State.Invalid = $true
                $State.Reason = 'Source context exceeds the supported nesting or item limit.'
                return
            }

            if ($null -eq $Value -or $Value -is [bool] -or $Value -is [string] -or
                $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or
                $Value -is [int64] -or $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
                if ($Value -is [string] -and $Value.Length -gt 4096) {
                    $State.Invalid = $true
                    $State.Reason = 'A source context string exceeds the supported length limit.'
                }
                return
            }

            if ($Value -is [System.Collections.IDictionary]) {
                if ($Value.Count -gt 64) {
                    $State.Invalid = $true
                    $State.Reason = 'A source context object exceeds the supported property limit.'
                    return
                }
                foreach ($key in $Value.Keys) {
                    if ($key -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$key)) {
                        $State.Invalid = $true
                        $State.Reason = 'Source context object keys must be non-empty strings.'
                        return
                    }
                    Test-ManifestSourceContextValue -Value $Value[$key] -Depth ($Depth + 1) -State $State
                    if ($State.Invalid) { return }
                }
                return
            }

            if (($Value -is [System.Collections.IEnumerable]) -and $Value -isnot [string]) {
                foreach ($item in $Value) {
                    Test-ManifestSourceContextValue -Value $item -Depth ($Depth + 1) -State $State
                    if ($State.Invalid) { return }
                }
                return
            }

            $State.Invalid = $true
            $State.Reason = 'Source context contains a value that cannot be represented as JSON.'
        }

        if ($context -isnot [System.Collections.IDictionary]) {
            $contextState.Invalid = $true
            $contextState.Reason = 'Source context must be a JSON object.'
        }
        else {
            Test-ManifestSourceContextValue -Value $context -Depth 0 -State $contextState
            if (-not $contextState.Invalid) {
                try {
                    $contextJson = ConvertTo-Json -InputObject $context -Depth 20 -Compress -ErrorAction Stop
                    if ([System.Text.Encoding]::UTF8.GetByteCount($contextJson) -gt 16384) {
                        $contextState.Invalid = $true
                        $contextState.Reason = 'Source context exceeds the 16 KiB serialized size limit.'
                    }
                }
                catch {
                    $contextState.Invalid = $true
                    $contextState.Reason = 'Source context could not be serialized as JSON.'
                }
            }
        }

        if ($contextState.Invalid) {
            $errors.Add([pscustomobject][ordered]@{
                Code = 'ManifestSourceContextInvalid'
                Path = '$.source.context'
                Message = $contextState.Reason
            })
        }
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

