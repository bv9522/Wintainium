function Read-WintainiumManifestFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        if (Test-Path -LiteralPath $Path -PathType Container) {
            throw [System.IO.IOException]::new("Manifest path '$Path' is a directory, not a file.")
        }

        throw [System.IO.FileNotFoundException]::new("Manifest file '$Path' was not found.", $Path)
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path

    [pscustomobject][ordered]@{
        Path = $resolvedPath
        Json = Get-Content -LiteralPath $resolvedPath -Raw -Encoding utf8 -ErrorAction Stop
    }
}
