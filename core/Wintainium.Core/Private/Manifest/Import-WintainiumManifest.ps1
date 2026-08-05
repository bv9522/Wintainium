function Import-WintainiumManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json')
    )

    try {
        $file = Read-WintainiumManifestFile -Path $Path
    }
    catch {
        return [pscustomobject][ordered]@{
            IsValid = $false
            Path = $Path
            Manifest = $null
            Errors = @([pscustomobject][ordered]@{
                    Code = 'ManifestFileReadFailed'
                    Path = '$'
                    Message = $_.Exception.Message
                })
        }
    }

    ConvertFrom-WintainiumManifestJson -Json $file.Json -Path $file.Path -SchemaPath $SchemaPath
}

