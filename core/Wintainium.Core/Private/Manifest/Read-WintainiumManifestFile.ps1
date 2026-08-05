function Read-WintainiumManifestFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    [pscustomobject][ordered]@{
        Path = $resolvedPath
        Json = Get-Content -LiteralPath $resolvedPath -Raw -Encoding utf8 -ErrorAction Stop
    }
}

