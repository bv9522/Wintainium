function Find-WintaniumManifestFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestRoot
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $ManifestRoot -ErrorAction Stop).Path
    Get-ChildItem -LiteralPath $resolvedRoot -Filter '*.json' -File -ErrorAction Stop |
        Sort-Object -Property FullName |
        ForEach-Object { $_.FullName }
}
