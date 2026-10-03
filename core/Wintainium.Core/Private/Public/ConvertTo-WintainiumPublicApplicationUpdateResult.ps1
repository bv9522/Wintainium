function ConvertTo-WintainiumPublicApplicationUpdateResult {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$LifecycleResult
    )

    ConvertTo-WintainiumPublicApplicationLifecycleResult -LifecycleResult $LifecycleResult
}
