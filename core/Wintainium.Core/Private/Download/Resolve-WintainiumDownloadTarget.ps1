function Resolve-WintainiumDownloadTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$DownloadRequest,

        [Parameter(Mandatory)]
        [string]$DownloadRoot
    )

    if ($null -eq $DownloadRequest) {
        throw [System.ArgumentNullException]::new('DownloadRequest')
    }

    if ([string]::IsNullOrWhiteSpace($DownloadRoot)) {
        throw [System.ArgumentException]::new('DownloadRoot cannot be empty.')
    }

    if (-not $DownloadRequest.PSObject.Properties['SelectedArtifact']) {
        throw [System.ArgumentException]::new('DownloadRequest is missing required property ''SelectedArtifact''.')
    }

    $artifact = $DownloadRequest.SelectedArtifact
    if ($null -eq $artifact -or -not $artifact.PSObject.Properties['Uri']) {
        throw [System.ArgumentException]::new('SelectedArtifact must contain a URI.')
    }

    $uri = $null
    if (-not [System.Uri]::TryCreate([string]$artifact.Uri, [System.UriKind]::Absolute, [ref]$uri)) {
        throw [System.ArgumentException]::new('SelectedArtifact URI must be an absolute URI.')
    }

    if ($uri.Scheme -notin @('https', 'http')) {
        throw [System.ArgumentException]::new("URI scheme '$($uri.Scheme)' is not supported by the download boundary.")
    }

    if ($uri.Scheme -eq 'http') {
        throw [System.ArgumentException]::new('HTTP download URIs are not permitted; HTTPS is required.')
    }

    $rawName = $null
    if ($artifact.PSObject.Properties['FileName']) {
        $rawName = [string]$artifact.FileName
    }
    if ([string]::IsNullOrWhiteSpace($rawName)) {
        $rawName = [System.IO.Path]::GetFileName($uri.AbsolutePath)
    }

    if ([string]::IsNullOrWhiteSpace($rawName) -or $rawName -in @('.', '..')) {
        throw [System.ArgumentException]::new('A usable artifact filename could not be determined.')
    }

    if ($rawName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        throw [System.ArgumentException]::new('Artifact filename contains invalid Windows filename characters.')
    }

    if ($rawName.Contains('/') -or $rawName.Contains('\') -or [System.IO.Path]::IsPathRooted($rawName)) {
        throw [System.ArgumentException]::new('Artifact filename must be a single filename and cannot contain path components.')
    }

    $reservedBaseName = [System.IO.Path]::GetFileNameWithoutExtension($rawName).TrimEnd('.')
    if ($reservedBaseName -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
        throw [System.ArgumentException]::new('Artifact filename uses a reserved Windows device name.')
    }

    $root = [System.IO.Path]::GetFullPath($DownloadRoot)
    $destination = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, $rawName))
    $rootWithSeparator = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if (-not $destination.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw [System.ArgumentException]::new('Resolved artifact destination escapes the Core-controlled download root.')
    }

    [pscustomobject][ordered]@{
        Uri = $uri.AbsoluteUri
        DownloadRoot = $root
        FileName = $rawName
        DestinationPath = $destination
    }
}
