function Import-WintaniumManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [string]$SchemaPath = (Join-Path -Path $script:WintaniumSchemaRoot -ChildPath 'application-manifest.schema.json')
    )

    try {
        $file = Read-WintaniumManifestFile -Path $Path
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

    ConvertFrom-WintaniumManifestJson -Json $file.Json -Path $file.Path -SchemaPath $SchemaPath
}
