function Find-WintainiumManifestFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestRoot
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $ManifestRoot -ErrorAction Stop).Path

    $manifests = @(
        Get-ChildItem -LiteralPath $resolvedRoot -Filter '*.json' -File -ErrorAction Stop |
            Sort-Object -Property FullName |
            ForEach-Object { $_.FullName }
    )

    return ,$manifests
}

