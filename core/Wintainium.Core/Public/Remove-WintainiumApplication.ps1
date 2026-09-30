function Remove-WintainiumApplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ManifestPath,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ManifestRoot,
        [string]$OperationId
    )

    $resolvedOperationId = [guid]::Empty
    if ([string]::IsNullOrWhiteSpace($OperationId)) {
        $resolvedOperationId = [guid]::NewGuid()
    }
    elseif (-not [guid]::TryParse($OperationId, [ref]$resolvedOperationId)) {
        return [pscustomobject][ordered]@{
            OperationId=$OperationId; IsSuccessful=$false; Status='RemovalFailed'
            Errors=@([pscustomobject][ordered]@{Code='OperationIdInvalid';Message='OperationId must be a valid GUID.'})
            Warnings=@()
        }
    }

    try {
        $root = [IO.Path]::GetFullPath($ManifestRoot)
        $target = [IO.Path]::GetFullPath($ManifestPath)
    }
    catch {
        return [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId.ToString(); IsSuccessful=$false; Status='RemovalFailed'
            Errors=@([pscustomobject][ordered]@{Code='ManifestPathInvalid';Message=$_.Exception.Message})
            Warnings=@()
        }
    }

    $rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $target.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetExtension($target) -ne '.json' -or
        [IO.Path]::GetFileName($target) -notlike '*.wintainium.json') {
        return [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId.ToString(); IsSuccessful=$false; Status='RemovalFailed'
            Errors=@([pscustomobject][ordered]@{Code='ManifestPathOutsideCollection';Message='The manifest is not a recognized Wintainium manifest inside the configured collection.'})
            Warnings=@()
        }
    }

    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        return [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId.ToString(); IsSuccessful=$false; Status='NotFound'
            Errors=@([pscustomobject][ordered]@{Code='ManifestNotFound';Message="Wintainium manifest '$target' was not found."})
            Warnings=@()
        }
    }

    try {
        Remove-Item -LiteralPath $target -Force -ErrorAction Stop
        [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId.ToString(); IsSuccessful=$true; Status='Removed'
            Errors=@(); Warnings=@()
        }
    }
    catch {
        [pscustomobject][ordered]@{
            OperationId=$resolvedOperationId.ToString(); IsSuccessful=$false; Status='RemovalFailed'
            Errors=@([pscustomobject][ordered]@{Code='ManifestRemovalFailed';Message=$_.Exception.Message})
            Warnings=@()
        }
    }
}
