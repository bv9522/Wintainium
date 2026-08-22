function Import-WintainiumManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json')
    )

    $baseResult = [ordered]@{
        IsValid = $false
        Path = $Path
        Manifest = $null
        Errors = @()
        Warnings = @()
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        $baseResult.Errors = @([pscustomobject][ordered]@{
                Code = 'ManifestFileNotFound'
                Path = '$'
                Message = "Manifest file '$Path' was not found."
            })
        return [pscustomobject]$baseResult
    }

    if (Test-Path -LiteralPath $Path -PathType Container) {
        $baseResult.Errors = @([pscustomobject][ordered]@{
                Code = 'ManifestPathInvalid'
                Path = '$'
                Message = "Manifest path '$Path' is a directory, not a file."
            })
        return [pscustomobject]$baseResult
    }

    if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
        $baseResult.Errors = @([pscustomobject][ordered]@{
                Code = 'ManifestSchemaInvalid'
                Path = '$'
                Message = "Manifest schema '$SchemaPath' was not found."
            })
        return [pscustomobject]$baseResult
    }

    try {
        $file = Read-WintainiumManifestFile -Path $Path
    }
    catch {
        $baseResult.Errors = @([pscustomobject][ordered]@{
                Code = 'ManifestReadFailed'
                Path = '$'
                Message = $_.Exception.Message
            })
        return [pscustomobject]$baseResult
    }

    $result = ConvertFrom-WintainiumManifestJson -Json $file.Json -Path $file.Path -SchemaPath $SchemaPath

    [pscustomobject][ordered]@{
        IsValid = $result.IsValid
        Path = $result.Path
        Manifest = $result.Manifest
        Errors = @($result.Errors)
        Warnings = @()
    }
}
