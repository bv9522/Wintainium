function Set-WintainiumApplicationDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$ApplicationDefinition,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestRoot,

        [Parameter()]
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json')
    )

    $applicationId = [string]$ApplicationDefinition.Id
    if ([string]::IsNullOrWhiteSpace($applicationId)) {
        throw [System.ArgumentException]::new('ApplicationDefinition must contain a non-empty Id.')
    }

    New-Item -ItemType Directory -Path $ManifestRoot -Force -ErrorAction Stop | Out-Null

    $fileName = "$applicationId.wintainium.json"
    $destinationPath = Join-Path -Path $ManifestRoot -ChildPath $fileName
    $tempPath = Join-Path -Path $ManifestRoot -ChildPath (".$fileName.$([guid]::NewGuid().Guid).tmp")

    try {
        $json = $ApplicationDefinition | ConvertTo-Json -Depth 20
        Set-Content -LiteralPath $tempPath -Value $json -Encoding utf8 -ErrorAction Stop

        if (-not (Test-WintainiumManifestSchema -ManifestPath $tempPath -SchemaPath $SchemaPath)) {
            throw [System.ArgumentException]::new("Application definition '$applicationId' does not satisfy the Wintainium manifest schema.")
        }

        Move-Item -LiteralPath $tempPath -Destination $destinationPath -Force -ErrorAction Stop
        return $destinationPath
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}
