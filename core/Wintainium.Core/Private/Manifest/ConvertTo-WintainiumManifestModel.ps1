function ConvertTo-WintainiumManifestModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest
    )

    # Schema validation occurs before this conversion. Keeping the full declarative
    # shape avoids embedding assumptions about any provider, installer, or
    # reconciliation plugin.
    [pscustomobject][ordered]@{
        ManifestVersion = $Manifest['manifestVersion']
        Id = $Manifest['id']
        Name = $Manifest['name']
        Description = $Manifest['description']
        Homepage = $Manifest['homepage']
        Publisher = $Manifest['publisher']
        Aliases = @($Manifest['aliases'])
        Documentation = $Manifest['documentation']
        Notes = $Manifest['notes']
        Deprecated = $Manifest['deprecated']
        Source = $Manifest['source']
        Installer = $Manifest['installer']
        Reconciliation = $Manifest['reconciliation']
        Release = $Manifest['release']
        Artifact = $Manifest['artifact']
    }
}
