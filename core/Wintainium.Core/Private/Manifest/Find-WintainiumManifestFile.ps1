function Find-WintainiumManifestFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestRoot,

        [switch]$Recurse
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $ManifestRoot -ErrorAction Stop).Path
    $getChildItemParameters = @{
        LiteralPath = $resolvedRoot
        Filter = '*.wintainium.json'
        File = $true
        ErrorAction = 'Stop'
    }

    if ($Recurse) {
        $getChildItemParameters.Recurse = $true
    }

    $manifests = @(
        Get-ChildItem @getChildItemParameters |
            Sort-Object -Property FullName |
            ForEach-Object { $_.FullName }
    )

    return $manifests
}
