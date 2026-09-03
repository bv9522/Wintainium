function Remove-WintainiumInstallationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Result
    )

    # Phase 6F deliberately has no mutable installation-result cleanup operation.
    # This placeholder is intentionally not exported or used; result construction
    # is immutable from the caller's perspective.
    return $Result
}
