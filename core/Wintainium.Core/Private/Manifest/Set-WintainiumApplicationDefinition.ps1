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

    New-Item -ItemType Directory -Path $ManifestRoot -Force -ErrorAction Stop | Out-Null

    $tempPath = Join-Path -Path $ManifestRoot -ChildPath (".application-definition.$([guid]::NewGuid().Guid).tmp")

    try {
        $json = $ApplicationDefinition | ConvertTo-Json -Depth 20
        Set-Content -LiteralPath $tempPath -Value $json -Encoding utf8 -ErrorAction Stop

        if (-not (Test-WintainiumManifestSchema -ManifestPath $tempPath -SchemaPath $SchemaPath)) {
            throw [System.ArgumentException]::new('Application definition does not satisfy the Wintainium manifest schema.')
        }

        $applicationId = [string]$ApplicationDefinition.Id
        $fileName = "$applicationId.wintainium.json"
        $destinationPath = Join-Path -Path $ManifestRoot -ChildPath $fileName

        Move-Item -LiteralPath $tempPath -Destination $destinationPath -Force -ErrorAction Stop
        return $destinationPath
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}
