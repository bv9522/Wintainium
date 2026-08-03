function Test-WintaniumManifestSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [string]$SchemaPath
    )

    $json = Get-Content -LiteralPath $ManifestPath -Raw -Encoding utf8 -ErrorAction Stop
    Test-WintaniumManifestJsonSchema -Json $json -SchemaPath $SchemaPath
}

function Test-WintaniumManifestJsonSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Json,

        [Parameter(Mandatory)]
        [string]$SchemaPath
    )

    try {
        return [bool](Test-Json -Json $json -SchemaFile $SchemaPath -ErrorAction Stop)
    }
    catch {
        # Test-Json throws for schema violations in PowerShell 7.4+.
        return $false
    }
}
