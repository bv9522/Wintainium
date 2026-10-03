function Invoke-WintainiumApplicationUpdateLifecycle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$ManifestPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$StateRoot,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$MachineArchitecture,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$DownloadRoot,
        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),
        [ValidateRange(1, 2147483647)] [int]$InstallerTimeoutMilliseconds = 600000,
        [System.Net.Http.HttpClient]$HttpClient,
        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
    )

    Invoke-WintainiumApplicationLifecycle @PSBoundParameters -OperationKind Update
}
