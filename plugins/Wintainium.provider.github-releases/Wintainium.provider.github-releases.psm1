function New-GitHubProviderResult {
    param(
        [Parameter(Mandatory)][string]$OperationId,
        [Parameter(Mandatory)][bool]$IsSuccessful,
        [Parameter(Mandatory)][string]$Status,
        [object[]]$Releases = @(),
        [object[]]$Errors = @(),
        [object[]]$Warnings = @(),
        [object[]]$LogEvents = @()
    )

    [pscustomobject][ordered]@{
        OperationId = $OperationId
        IsSuccessful = $IsSuccessful
        Status = $Status
        Releases = @($Releases)
        Errors = @($Errors)
        Warnings = @($Warnings)
        LogEvents = @($LogEvents)
    }
}

function New-GitHubProviderError {
    param(
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Message
    )

    [pscustomobject][ordered]@{
        Code = $Code
        Message = $Message
    }
}

function Get-GitHubHttpStatusCode {
    param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord)

    try {
        $response = $ErrorRecord.Exception.Response
        if ($null -ne $response) {
            if ($response.StatusCode -is [int]) {
                return [int]$response.StatusCode
            }

            return [int]$response.StatusCode.value__
        }

        if ($ErrorRecord.Exception.Data.Contains('StatusCode')) {
            return [int]$ErrorRecord.Exception.Data['StatusCode']
        }
    }
    catch {
        return $null
    }

    return $null
}

function ConvertTo-GitHubArtifactFormat {
    param([Parameter(Mandatory)][string]$FileName)

    switch ([IO.Path]::GetExtension($FileName).ToLowerInvariant()) {
        '.zip' { return 'zip' }
        '.msi' { return 'msi' }
        '.exe' { return 'exe' }
        default { return 'unknown' }
    }
}

function ConvertTo-GitHubArtifactArchitecture {
    param([Parameter(Mandatory)][string]$FileName)

    $name = $FileName.ToLowerInvariant()

    if ($name -match '(^|[^a-z0-9])(arm64|aarch64)([^a-z0-9]|$)') {
        return 'arm64'
    }

    if ($name -match '(^|[^a-z0-9])(x64|amd64)([^a-z0-9]|$)') {
        return 'x64'
    }

    if ($name -match '(^|[^a-z0-9])(x86|win32|i[3-6]86)([^a-z0-9]|$)') {
        return 'x86'
    }

    return 'unknown'
}

function ConvertFrom-GitHubRelease {
    param([Parameter(Mandatory)][object]$Release)

    foreach ($property in @('id', 'tag_name', 'prerelease', 'assets')) {
        if (-not $Release.PSObject.Properties[$property]) {
            throw "GitHub release response is missing '$property'."
        }
    }

    $artifacts = foreach ($asset in @($Release.assets)) {
        if ($null -eq $asset) {
            throw 'GitHub release asset response contains a null asset.'
        }

        foreach ($property in @('browser_download_url', 'name', 'size')) {
            if (-not $asset.PSObject.Properties[$property]) {
                throw "GitHub release asset response is missing '$property'."
            }
        }

        $uri = [string]$asset.browser_download_url
        $fileName = [string]$asset.name
        if ([string]::IsNullOrWhiteSpace($uri) -or [string]::IsNullOrWhiteSpace($fileName)) {
            throw 'GitHub release asset response contains an empty download URL or filename.'
        }

        if ($uri -notmatch '^https://') {
            throw "GitHub release asset download URL '$uri' is not an HTTPS URI."
        }

        $size = $null
        try {
            $size = [long]$asset.size
        }
        catch {
            throw "GitHub release asset '$fileName' has an invalid size."
        }

        if ($size -lt 0) {
            throw "GitHub release asset '$fileName' has a negative size."
        }

        [pscustomobject][ordered]@{
            Uri = $uri
            FileName = $fileName
            Format = ConvertTo-GitHubArtifactFormat -FileName $fileName
            Architecture = ConvertTo-GitHubArtifactArchitecture -FileName $fileName
            Size = $size
            Hashes = @()
            Signature = $null
        }
    }

    $publishedAt = $null
    if ($Release.PSObject.Properties['published_at'] -and $Release.published_at) {
        try {
            $publishedAt = [DateTimeOffset]$Release.published_at
        }
        catch {
            throw "GitHub release 'published_at' is not a valid timestamp."
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$Release.id) -or [string]::IsNullOrWhiteSpace([string]$Release.tag_name)) {
        throw 'GitHub release response contains an empty id or tag_name.'
    }

    [pscustomobject][ordered]@{
        ReleaseId = [string]$Release.id
        Version = [string]$Release.tag_name
        Channel = if ([bool]$Release.prerelease) { 'prerelease' } else { 'stable' }
        PublishedAt = $publishedAt
        Artifacts = @($artifacts)
    }
}

function Invoke-WintainiumProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Request
    )

    $operationId = [string]$Request.OperationId
    $settings = $Request.Settings

    if ($null -eq $settings) {
        return New-GitHubProviderResult -OperationId $operationId -IsSuccessful $false -Status 'ConfigurationInvalid' -Errors @(
            (New-GitHubProviderError -Code 'GitHubRepositoryMissing' -Message 'GitHub provider setting repository is required.')
        )
    }

    $hasRepositorySetting = if ($settings -is [System.Collections.IDictionary]) {
        $settings.Contains('repository')
    }
    else {
        $null -ne $settings.PSObject.Properties['repository']
    }

    if (-not $hasRepositorySetting -or [string]::IsNullOrWhiteSpace([string]$settings.repository)) {
        return New-GitHubProviderResult -OperationId $operationId -IsSuccessful $false -Status 'ConfigurationInvalid' -Errors @(
            (New-GitHubProviderError -Code 'GitHubRepositoryMissing' -Message 'GitHub provider setting repository is required.')
        )
    }

    $repository = [string]$settings.repository
    if ($repository -notmatch '^[^/\s]+/[^/\s]+$') {
        return New-GitHubProviderResult -OperationId $operationId -IsSuccessful $false -Status 'ConfigurationInvalid' -Errors @(
            (New-GitHubProviderError -Code 'GitHubRepositoryInvalid' -Message "GitHub repository '$repository' must use the owner/repository form.")
        )
    }

    $maxPages = 10
    $hasMaxPagesSetting = if ($settings -is [System.Collections.IDictionary]) {
        $settings.Contains('maxPages')
    }
    else {
        $null -ne $settings.PSObject.Properties['maxPages']
    }

    if ($hasMaxPagesSetting -and $null -ne $settings.maxPages) {
        try {
            $maxPages = [int]$settings.maxPages
        }
        catch {
            return New-GitHubProviderResult -OperationId $operationId -IsSuccessful $false -Status 'ConfigurationInvalid' -Errors @(
                (New-GitHubProviderError -Code 'GitHubMaxPagesInvalid' -Message 'GitHub provider setting maxPages must be an integer.')
            )
        }
    }

    if ($maxPages -lt 1 -or $maxPages -gt 20) {
        return New-GitHubProviderResult -OperationId $operationId -IsSuccessful $false -Status 'ConfigurationInvalid' -Errors @(
            (New-GitHubProviderError -Code 'GitHubMaxPagesInvalid' -Message 'GitHub provider setting maxPages must be between 1 and 20.')
        )
    }

    $repositoryParts = $repository.Split('/', 2)
    $encodedOwner = [uri]::EscapeDataString($repositoryParts[0])
    $encodedRepositoryName = [uri]::EscapeDataString($repositoryParts[1])
    $releases = [System.Collections.Generic.List[object]]::new()

    for ($page = 1; $page -le $maxPages; $page++) {
        $uri = "https://api.github.com/repos/$encodedOwner/$encodedRepositoryName/releases?per_page=100&page=$page"
        try {
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers @{
                Accept = 'application/vnd.github+json'
                'User-Agent' = 'Wintainium/0.1'
            } -ErrorAction Stop
        }
        catch {
            $statusCode = Get-GitHubHttpStatusCode -ErrorRecord $_
            $errorCode = switch ($statusCode) {
                404 { 'GitHubRepositoryNotFound' }
                401 { 'GitHubAuthenticationFailed' }
                403 { 'GitHubSourceUnavailable' }
                429 { 'GitHubSourceUnavailable' }
                default { if ($statusCode -ge 500) { 'GitHubSourceUnavailable' } else { 'GitHubRequestFailed' } }
            }
            $status = switch ($errorCode) {
                'GitHubRepositoryNotFound' { 'SourceNotFound' }
                'GitHubAuthenticationFailed' { 'AuthenticationFailed' }
                'GitHubSourceUnavailable' { 'SourceUnavailable' }
                default { 'SourceUnavailable' }
            }

            return New-GitHubProviderResult -OperationId $operationId -IsSuccessful $false -Status $status -Errors @(
                (New-GitHubProviderError -Code $errorCode -Message $_.Exception.Message)
            )
        }

        # PowerShell can unwrap a one-element array returned by a mocked command
        # into the element itself. GitHub's releases endpoint still represents
        # that response as a collection, so normalize both shapes here. A scalar
        # release is therefore treated as a one-item page rather than as an
        # invalid response.
        if ($null -eq $response) {
            $pageItems = @()
        }
        elseif ($response -is [string]) {
            return New-GitHubProviderResult -OperationId $operationId -IsSuccessful $false -Status 'UpstreamResponseInvalid' -Errors @(
                (New-GitHubProviderError -Code 'GitHubResponseInvalid' -Message 'GitHub releases response was not a release collection.')
            )
        }
        elseif ($response -is [System.Collections.IEnumerable]) {
            $pageItems = @($response)
        }
        else {
            $pageItems = @($response)
        }

        foreach ($release in $pageItems) {
            try {
                $releases.Add((ConvertFrom-GitHubRelease -Release $release))
            }
            catch {
                return New-GitHubProviderResult -OperationId $operationId -IsSuccessful $false -Status 'UpstreamResponseInvalid' -Errors @(
                    (New-GitHubProviderError -Code 'GitHubReleaseInvalid' -Message $_.Exception.Message)
                )
            }
        }

        if ($pageItems.Count -lt 100) {
            break
        }
    }

    if ($releases.Count -eq 0) {
        return New-GitHubProviderResult -OperationId $operationId -IsSuccessful $true -Status 'NoReleasesFound'
    }

    New-GitHubProviderResult -OperationId $operationId -IsSuccessful $true -Status 'Success' -Releases $releases.ToArray()
}

Export-ModuleMember -Function Invoke-WintainiumProvider
