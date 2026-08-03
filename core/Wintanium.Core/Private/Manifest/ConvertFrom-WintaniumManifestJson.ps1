function ConvertFrom-WintaniumManifestJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Json,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$SchemaPath
    )

    $errors = [System.Collections.Generic.List[object]]::new()
    $rawManifest = $null
    $model = $null

    try {
        $rawManifest = ConvertFrom-Json -InputObject $Json -AsHashtable -Depth 100 -ErrorAction Stop
    }
    catch {
        $errors.Add([pscustomobject][ordered]@{
                Code = 'ManifestJsonInvalid'
                Path = '$'
                Message = $_.Exception.Message
            })
    }

    if ($null -ne $rawManifest -and -not (Test-WintaniumManifestJsonSchema -Json $Json -SchemaPath $SchemaPath)) {
        $errors.Add([pscustomobject][ordered]@{
                Code = 'ManifestSchemaInvalid'
                Path = '$'
                Message = 'The manifest does not satisfy the application manifest schema.'
            })
    }

    if ($errors.Count -eq 0) {
        foreach ($validationError in @(Test-WintaniumManifestSemantics -Manifest $rawManifest)) {
            $errors.Add($validationError)
        }

        if ($errors.Count -eq 0) {
            $model = ConvertTo-WintaniumManifestModel -Manifest $rawManifest
        }
    }

    [pscustomobject][ordered]@{
        IsValid = $errors.Count -eq 0
        Path = $Path
        Manifest = $model
        Errors = $errors.ToArray()
    }
}
