function Set-WintainiumApplicationIconOverride {
    <#
    .SYNOPSIS
    Sets or clears the user-selected icon override for an application manifest.

    .DESCRIPTION
    Persists only the user override. Any provider/Core automatic icon metadata remains
    intact. The command validates the resulting manifest against the application
    schema before replacing the existing file.

    .PARAMETER ManifestPath
    Path to the application manifest.

    .PARAMETER IconUri
    Absolute file, HTTP, or HTTPS URI to use as the user-selected icon. Omit or pass
    an empty value to reset the override to automatic icon behavior.

    .PARAMETER SchemaPath
    Path to the application manifest JSON schema.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [AllowEmptyString()]
        [string]$IconUri,

        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),

        [string]$OperationId = ([guid]::NewGuid().Guid)
    )

    $errors = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        $errors.Add([pscustomobject][ordered]@{
                Code = 'ManifestNotFound'
                Path = '$'
                Message = "Application manifest '$ManifestPath' was not found."
            })
    }

    if ($errors.Count -eq 0 -and -not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
        $errors.Add([pscustomobject][ordered]@{
                Code = 'ManifestSchemaNotFound'
                Path = '$'
                Message = "Application manifest schema '$SchemaPath' was not found."
            })
    }

    $manifest = $null
    if ($errors.Count -eq 0) {
        try {
            $manifest = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        }
        catch {
            $errors.Add([pscustomobject][ordered]@{
                    Code = 'ManifestReadFailed'
                    Path = '$'
                    Message = $_.Exception.Message
                })
        }
    }

    if ($errors.Count -eq 0) {
        if ($IconUri) {
            $uri = $null
            if (-not [Uri]::TryCreate($IconUri.Trim(), [UriKind]::Absolute, [ref]$uri) -or
                $uri.Scheme -notin @('file', 'http', 'https')) {
                $errors.Add([pscustomobject][ordered]@{
                        Code = 'ApplicationIconUriInvalid'
                        Path = '$.icon.overrideUri'
                        Message = 'Icon URI must be an absolute file, HTTP, or HTTPS URI.'
                    })
            }
            else {
                if (-not $manifest.ContainsKey('icon') -or $manifest.icon -isnot [hashtable]) {
                    $manifest.icon = [ordered]@{}
                }
                $manifest.icon.overrideUri = $uri.AbsoluteUri
            }
        }
        elseif ($manifest.ContainsKey('icon') -and $manifest.icon -is [hashtable]) {
            $manifest.icon.Remove('overrideUri')
            if ($manifest.icon.Count -eq 0) {
                $manifest.Remove('icon')
            }
        }
    }

    $json = $null
    if ($errors.Count -eq 0) {
        try {
            $json = $manifest | ConvertTo-Json -Depth 100
            if (-not (Test-Json -Json $json -SchemaFile $SchemaPath -ErrorAction Stop)) {
                $errors.Add([pscustomobject][ordered]@{
                        Code = 'ManifestValidationFailed'
                        Path = '$'
                        Message = 'The updated application manifest does not satisfy the application manifest schema.'
                    })
            }
        }
        catch {
            $errors.Add([pscustomobject][ordered]@{
                    Code = 'ManifestValidationFailed'
                    Path = '$'
                    Message = $_.Exception.Message
                })
        }
    }

    if ($errors.Count -eq 0) {
        $temporaryPath = "$ManifestPath.$OperationId.tmp"
        try {
            Set-Content -LiteralPath $temporaryPath -Value $json -Encoding utf8 -ErrorAction Stop
            Move-Item -LiteralPath $temporaryPath -Destination $ManifestPath -Force -ErrorAction Stop
        }
        catch {
            if (Test-Path -LiteralPath $temporaryPath) {
                Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
            }
            $errors.Add([pscustomobject][ordered]@{
                    Code = 'ManifestWriteFailed'
                    Path = '$'
                    Message = $_.Exception.Message
                })
        }
    }

    [pscustomobject][ordered]@{
        OperationId = $OperationId
        IsSuccessful = $errors.Count -eq 0
        Status = if ($errors.Count -eq 0) { 'IconOverrideUpdated' } else { 'IconOverrideUpdateFailed' }
        Errors = $errors.ToArray()
        Warnings = $warnings.ToArray()
    }
}
