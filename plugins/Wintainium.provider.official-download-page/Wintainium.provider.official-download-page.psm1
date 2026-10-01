
function New-OfficialDownloadPageReleaseDiscoveryResult {
    param(
        [Parameter(Mandatory)][string]$OperationId,
        [Parameter(Mandatory)][bool]$IsSuccessful,
        [Parameter(Mandatory)][string]$Status,
        [object[]]$Releases = @(),
        [object[]]$Errors = @(),
        [object[]]$Warnings = @()
    )
    [pscustomobject][ordered]@{
        OperationId=$OperationId; IsSuccessful=$IsSuccessful; Status=$Status
        Releases=@($Releases); Errors=@($Errors); Warnings=@($Warnings); LogEvents=@()
    }
}

function ConvertTo-OfficialDownloadPageArtifactFormat {
    param([Parameter(Mandatory)][string]$FileName)
    switch ([IO.Path]::GetExtension($FileName).ToLowerInvariant()) {
        '.zip' { 'zip'; break }
        '.msi' { 'msi'; break }
        '.exe' { 'exe'; break }
        default { 'unknown' }
    }
}

function ConvertTo-OfficialDownloadPageArtifactArchitecture {
    param([Parameter(Mandatory)][string]$Value)
    $name=$Value.ToLowerInvariant()
    if ($name -match '(^|[^a-z0-9])(arm64|aarch64)([^a-z0-9]|$)') { return 'arm64' }
    if ($name -match '(^|[^a-z0-9])(x64|amd64|64-bit|64bit)([^a-z0-9]|$)') { return 'x64' }
    if ($name -match '(^|[^a-z0-9])(x86|win32|i[3-6]86|32-bit|32bit)([^a-z0-9]|$)') { return 'x86' }
    return 'unknown'
}

function ConvertFrom-OfficialDownloadPageReleaseSection {
    param(
        [Parameter(Mandatory)][string]$Heading,
        [Parameter(Mandatory)][string]$Body,
        [Parameter(Mandatory)][Uri]$BaseUri
    )

    $headingText=ConvertFrom-OfficialDownloadPageHtmlText $Heading
    if ([string]::IsNullOrWhiteSpace($headingText)) { return $null }

    $versionMatch=[regex]::Match($headingText,'(?i)(?<![a-z0-9])v?([0-9]+(?:\.[0-9]+){1,3})(?![a-z0-9])')
    if (-not $versionMatch.Success) { return $null }
    $version=$versionMatch.Groups[1].Value

    $publishedAt=$null
    $dateMatch=[regex]::Match($headingText,'(?<!\d)(20\d{2})[-./](\d{1,2})[-./](\d{1,2})(?!\d)')
    if ($dateMatch.Success) {
        try { $publishedAt=[DateTimeOffset]::ParseExact(
            "$($dateMatch.Groups[1].Value)-$($dateMatch.Groups[2].Value.PadLeft(2,'0'))-$($dateMatch.Groups[3].Value.PadLeft(2,'0'))",
            'yyyy-MM-dd',
            [Globalization.CultureInfo]::InvariantCulture
        ) } catch {}
    }

    $releaseText=ConvertFrom-OfficialDownloadPageHtmlText $Body
    $links=[regex]::Matches($Body,'<a\b[^>]*href\s*=\s*["'']([^"'']+)["''][^>]*>(.*?)</a\s*>',[Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $artifacts=[System.Collections.Generic.List[object]]::new()

    foreach ($link in $links) {
        $href=$link.Groups[1].Value
        $label=ConvertFrom-OfficialDownloadPageHtmlText $link.Groups[2].Value
        if ([string]::IsNullOrWhiteSpace($href)) { continue }
        try { $uri=[Uri]::new($BaseUri,$href) } catch { continue }
        if ($uri.Scheme -notin @('http','https')) { continue }

        $fileName=[IO.Path]::GetFileName($uri.AbsolutePath)
        if ([string]::IsNullOrWhiteSpace($fileName)) { $fileName=$label }
        $format=ConvertTo-OfficialDownloadPageArtifactFormat -FileName $fileName
        if ($format -eq 'unknown') { continue }

        $architecture=ConvertTo-OfficialDownloadPageArtifactArchitecture "$fileName $label $releaseText"
        $artifacts.Add([pscustomobject][ordered]@{
            Uri=$uri.AbsoluteUri
            FileName=$fileName
            Format=$format
            Architecture=$architecture
            Size=$null
            Hashes=@()
            Signature=$null
        })
    }

    if ($artifacts.Count -eq 0) { return $null }

    $releaseKey="$($BaseUri.Host.ToLowerInvariant())|$version|$($publishedAt)"
    $hash=[Security.Cryptography.SHA256]::Create()
    try {
        $bytes=[Text.Encoding]::UTF8.GetBytes($releaseKey)
        $digest=[Convert]::ToHexString($hash.ComputeHash($bytes)).ToLowerInvariant()
    }
    finally { $hash.Dispose() }

    [pscustomobject][ordered]@{
        ReleaseId="official.$digest"
        Version=$version
        Channel='stable'
        PublishedAt=$publishedAt
        Artifacts=@($artifacts)
    }
}

function Invoke-WintainiumProviderReleaseDiscovery {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Request)

    $operationId=[string]$Request.OperationId
    $settings=$Request.Settings
    $pageUri=$null

    if ($settings -is [System.Collections.IDictionary] -and $settings.Contains('pageUri')) {
        $pageUri=[string]$settings.pageUri
    }
    elseif ($null -ne $settings -and $settings.PSObject.Properties['pageUri']) {
        $pageUri=[string]$settings.pageUri
    }

    try { $baseUri=[Uri]$pageUri } catch {
        return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'ConfigurationInvalid' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageReleasePageInvalid' 'Official download page setting pageUri must be a valid URI.')
        )
    }

    if (-not $baseUri.IsAbsoluteUri -or $baseUri.Scheme -notin @('http','https')) {
        return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'ConfigurationInvalid' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageReleasePageInvalid' 'Official download page setting pageUri must use HTTP or HTTPS.')
        )
    }

    try {
        $response=Invoke-WebRequest -Method Get -Uri $baseUri.AbsoluteUri -MaximumRedirection 5 -TimeoutSec 30 -ErrorAction Stop
        $html=[string]$response.Content
    }
    catch {
        return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'SourceUnavailable' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageReleaseRequestFailed' $_.Exception.Message)
        )
    }

    if ([string]::IsNullOrWhiteSpace($html)) {
        return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'UpstreamResponseInvalid' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageReleaseContentEmpty' 'The official download page returned an empty HTML document.')
        )
    }

    $headingMatches=[regex]::Matches($html,'<h([1-6])\b[^>]*>(.*?)</h\1\s*>',[Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $releases=[System.Collections.Generic.List[object]]::new()

    for($i=0;$i -lt $headingMatches.Count;$i++) {
        $heading=$headingMatches[$i]
        $nextStart=if($i+1 -lt $headingMatches.Count){$headingMatches[$i+1].Index}else{$html.Length}
        $bodyStart=$heading.Index+$heading.Length
        if($bodyStart -ge $nextStart){continue}
        $body=$html.Substring($bodyStart,$nextStart-$bodyStart)
        try {
            $release=ConvertFrom-OfficialDownloadPageReleaseSection -Heading $heading.Groups[2].Value -Body $body -BaseUri $baseUri
            if($null -ne $release){$releases.Add($release)}
        }
        catch {
            return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'UpstreamResponseInvalid' -Errors @(
                (New-OfficialDownloadPageError 'OfficialDownloadPageReleaseInvalid' $_.Exception.Message)
            )
        }
    }

    if($releases.Count -eq 0){
        return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $true -Status 'NoReleasesFound'
    }

    New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $true -Status 'Success' -Releases $releases.ToArray()
}

function New-OfficialDownloadPageSourceResolutionResult {
    param([Parameter(Mandatory)][string]$OperationId,[Parameter(Mandatory)][bool]$IsSuccessful,[Parameter(Mandatory)][string]$Status,[object]$Source=$null,[object[]]$Errors=@(),[object[]]$Warnings=@(),[object[]]$LogEvents=@())
    [pscustomobject][ordered]@{OperationId=$OperationId;IsSuccessful=$IsSuccessful;Status=$Status;Source=$Source;Errors=@($Errors);Warnings=@($Warnings);LogEvents=@($LogEvents)}
}
function New-OfficialDownloadPageError {
    param([Parameter(Mandatory)][string]$Code,[Parameter(Mandatory)][string]$Message)
    [pscustomobject][ordered]@{Code=$Code;Message=$Message}
}
function ConvertFrom-OfficialDownloadPageHtmlText {
    param([AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return $null }
    [System.Net.WebUtility]::HtmlDecode(($Value -replace '<[^>]+>',' ')) -replace '\s+',' ' | ForEach-Object {$_.Trim()}
}
function Get-OfficialDownloadPageMetaValue {
    param([Parameter(Mandatory)][string]$Html,[Parameter(Mandatory)][string[]]$Names)
    $tags=[regex]::Matches($Html,'<meta\b[^>]*>',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($name in $Names) {
        foreach ($tag in $tags) {
            $tagText=$tag.Value
            $nameMatch=[regex]::Match($tagText,'\b(?:name|property)\s*=\s*["'']([^"'']+)["'']',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if (-not $nameMatch.Success -or $nameMatch.Groups[1].Value -ine $name) { continue }
            $contentMatch=[regex]::Match($tagText,'\bcontent\s*=\s*["'']([^"'']*)["'']',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($contentMatch.Success) {
                $value=ConvertFrom-OfficialDownloadPageHtmlText $contentMatch.Groups[1].Value
                if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
            }
        }
    }
    return $null
}
function Get-OfficialDownloadPageTitle {
    param([Parameter(Mandatory)][string]$Html)
    $match=[regex]::Match($Html,'<title\b[^>]*>(.*?)</title\s*>',[Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) { return ConvertFrom-OfficialDownloadPageHtmlText $match.Groups[1].Value }
    return $null
}
function Get-OfficialDownloadPageCanonicalUri {
    param([Parameter(Mandatory)][string]$Html,[Parameter(Mandatory)][Uri]$BaseUri)
    $tags=[regex]::Matches($Html,'<link\b[^>]*>',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($tag in $tags) {
        $tagText=$tag.Value
        $relMatch=[regex]::Match($tagText,'\brel\s*=\s*["'']([^"'']+)["'']',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $relMatch.Success -or $relMatch.Groups[1].Value -notmatch '(?i)(^|\s)canonical(\s|$)') { continue }
        $hrefMatch=[regex]::Match($tagText,'\bhref\s*=\s*["'']([^"'']+)["'']',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $hrefMatch.Success) { continue }
        try {
            $uri=[Uri]::new($BaseUri,$hrefMatch.Groups[1].Value)
            if ($uri.Scheme -in @('http','https')) { return $uri.AbsoluteUri }
        } catch {}
    }
    return $BaseUri.AbsoluteUri
}
function Get-OfficialDownloadPageImageAlt {
    param([Parameter(Mandatory)][string]$Html)
    $tags=[regex]::Matches($Html,'<img\b[^>]*>',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($tag in $tags) {
        $altMatch=[regex]::Match($tag.Value,'\balt\s*=\s*["'']([^"'']+)["'']',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($altMatch.Success) {
            $value=ConvertFrom-OfficialDownloadPageHtmlText $altMatch.Groups[1].Value
            if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
        }
    }
    return $null
}
function Get-OfficialDownloadPagePublisher {
    param([Parameter(Mandatory)][string]$Html)
    foreach ($candidate in @(
        (Get-OfficialDownloadPageMetaValue -Html $Html -Names @('publisher')),
        (Get-OfficialDownloadPageMetaValue -Html $Html -Names @('og:site_name'))
    )) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) { return $candidate }
    }

    $title=Get-OfficialDownloadPageTitle -Html $Html
    if ($title -match '(?i)\s[-–—]\s*([^|]+?)\s*$') {
        $candidate=$matches[1].Trim()
        if ($candidate -and $candidate -notmatch '(?i)^(download|downloads)$') { return $candidate }
    }

    return $null
}
function Get-OfficialDownloadPageHeading {
    param([Parameter(Mandatory)][string]$Html)
    $match=[regex]::Match($Html,'<h1\b[^>]*>(.*?)</h1\s*>',[Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) { return ConvertFrom-OfficialDownloadPageHtmlText $match.Groups[1].Value }
    return $null
}
function Get-OfficialDownloadPageApplicationName {
    param([Parameter(Mandatory)][string]$Html)
    foreach ($candidate in @(
        (Get-OfficialDownloadPageMetaValue -Html $Html -Names @('application-name')),
        (Get-OfficialDownloadPageMetaValue -Html $Html -Names @('og:site_name')),
        (Get-OfficialDownloadPageMetaValue -Html $Html -Names @('og:title')),
        (Get-OfficialDownloadPageHeading -Html $Html),
        (Get-OfficialDownloadPageImageAlt -Html $Html),
        (Get-OfficialDownloadPageTitle -Html $Html)
    )) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            $name=$candidate -replace '\s*[|–—-]\s*(download|downloads|official download page)\s*$',''
            $name=$name.Trim()
            if ($name -and $name -notmatch '(?i)^(download|downloads|official download page)$') { return $name }
        }
    }
    return $null
}
function Invoke-WintainiumProvider {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Request)

    if ($null -eq $Request -or [string]::IsNullOrWhiteSpace([string]$Request.OperationId)) {
        return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId ([guid]::NewGuid().ToString()) -IsSuccessful $false -Status 'ConfigurationInvalid' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageReleaseRequestInvalid' 'A valid release discovery operation request is required.')
        )
    }

    Invoke-WintainiumProviderReleaseDiscovery -Request $Request
}

function Invoke-WintainiumProviderSourceResolution {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Request)
    $operationId=[string]$Request.OperationId
    try {$sourceUri=[Uri]([string]$Request.SourceUri)} catch {
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceInvalid' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageUriInvalid' 'The supplied source URL is not a valid URI.')
    }
    if (-not $sourceUri.IsAbsoluteUri -or $sourceUri.Scheme -notin @('http','https')) {
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceUnsupported' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageSchemeUnsupported' 'Official download page resolution requires HTTP or HTTPS.')
    }
    if ($sourceUri.Host -ieq 'github.com' -or $sourceUri.Host -ieq 'www.github.com') {
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceUnsupported' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageHostUnsupported' 'GitHub sources are resolved by the GitHub provider.')
    }
    try {$response=Invoke-WebRequest -Method Get -Uri $sourceUri.AbsoluteUri -MaximumRedirection 5 -TimeoutSec 30 -ErrorAction Stop} catch {
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceUnavailable' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageRequestFailed' $_.Exception.Message)
    }
    $contentType=''
    if ($response.Headers -and $response.Headers['Content-Type']) {$contentType=[string]$response.Headers['Content-Type']}
    if ($contentType -and $contentType -notmatch '(?i)text/html|application/xhtml\+xml') {
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceUnsupported' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageContentTypeUnsupported' "Unsupported content type '$contentType'.")
    }
    $html=[string]$response.Content
    if ([string]::IsNullOrWhiteSpace($html)) {
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceResponseInvalid' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageContentEmpty' 'The source returned an empty HTML document.')
    }
    $canonical=Get-OfficialDownloadPageCanonicalUri -Html $html -BaseUri $sourceUri
    $name=Get-OfficialDownloadPageApplicationName -Html $html
    if ([string]::IsNullOrWhiteSpace($name)) {
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceResponseInvalid' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageIdentityMissing' 'The page did not expose a usable application name in supported identity metadata or headings.')
    }
    $hostId=$sourceUri.Host.ToLowerInvariant() -replace '[^a-z0-9]+','.'
    $pathId=$sourceUri.AbsolutePath.Trim('/').ToLowerInvariant() -replace '[^a-z0-9]+','.'
    $pathId=$pathId.Trim('.')
    $applicationId=if ($pathId) {"web.$hostId.$pathId"} else {"web.$hostId"}
    $publisher=Get-OfficialDownloadPagePublisher -Html $html
    $source=[pscustomobject][ordered]@{
        ApplicationId=$applicationId;Name=$name;Publisher=$publisher;Homepage=$canonical;CanonicalUri=$canonical
        ProviderId='Wintainium.provider.official-download-page';ProviderContractVersion='1'
        ProviderSettings=[ordered]@{pageUri=$canonical}
        SourceContext=[pscustomobject][ordered]@{sourceFamily='official-download-page';contentType=if($contentType){$contentType}else{'text/html'}}
    }
    New-OfficialDownloadPageSourceResolutionResult $operationId $true 'Resolved' $source
}
function New-OfficialDownloadPageIconDiscoveryResult {
    param(
        [Parameter(Mandatory)][string]$OperationId,
        [Parameter(Mandatory)][bool]$IsSuccessful,
        [Parameter(Mandatory)][string]$Status,
        [string]$IconUri = $null,
        [object[]]$Errors = @(),
        [object[]]$Warnings = @()
    )
    [pscustomobject][ordered]@{
        OperationId=$OperationId; IsSuccessful=$IsSuccessful; Status=$Status
        IconUri=$IconUri; Errors=@($Errors); Warnings=@($Warnings)
    }
}

function Invoke-WintainiumProviderIconDiscovery {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Request)

    $operationId=[string]$Request.OperationId
    $source=$Request.Source
    if ($null -eq $source -or [string]::IsNullOrWhiteSpace([string]$source.Homepage)) {
        return New-OfficialDownloadPageIconDiscoveryResult -OperationId $operationId -IsSuccessful $true -Status 'NoTrustedIcon'
    }

    try { $homepage=[Uri]$source.Homepage } catch {
        return New-OfficialDownloadPageIconDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'IconDiscoveryInvalidRequest' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageIconHomepageInvalid' 'The resolved official homepage is not a valid URI.')
        )
    }

    if (-not $homepage.IsAbsoluteUri -or $homepage.Scheme -notin @('http','https')) {
        return New-OfficialDownloadPageIconDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'IconDiscoveryInvalidRequest' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageIconHomepageInvalid' 'The resolved official homepage must use HTTP or HTTPS.')
        )
    }

    try {
        $response=Invoke-WebRequest -Method Get -Uri $homepage.AbsoluteUri -MaximumRedirection 5 -TimeoutSec 30 -ErrorAction Stop
        $html=[string]$response.Content
    }
    catch {
        return New-OfficialDownloadPageIconDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'IconDiscoveryUnavailable' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageIconRequestFailed' $_.Exception.Message)
        )
    }

    $tags=[regex]::Matches($html,'<link\b[^>]*>',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($tag in $tags) {
        $relMatch=[regex]::Match($tag.Value,'\brel\s*=\s*["'']([^"'']+)["'']',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $relMatch.Success) { continue }
        $rels=[string]$relMatch.Groups[1].Value -split '\s+'
        $isIcon=$rels | Where-Object { $_ -ieq 'icon' -or $_ -ieq 'shortcut' -or $_ -ieq 'apple-touch-icon' }
        if (-not $isIcon) { continue }

        $hrefMatch=[regex]::Match($tag.Value,'\bhref\s*=\s*["'']([^"'']+)["'']',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $hrefMatch.Success) { continue }
        try { $iconUri=[Uri]::new($homepage,$hrefMatch.Groups[1].Value) } catch { continue }
        if ($iconUri.Scheme -in @('http','https') -and $iconUri.Host -eq $homepage.Host) {
            return New-OfficialDownloadPageIconDiscoveryResult -OperationId $operationId -IsSuccessful $true -Status 'IconResolved' -IconUri $iconUri.AbsoluteUri
        }
    }

    New-OfficialDownloadPageIconDiscoveryResult -OperationId $operationId -IsSuccessful $true -Status 'NoTrustedIcon'
}

Export-ModuleMember -Function Invoke-WintainiumProvider, Invoke-WintainiumProviderSourceResolution, Invoke-WintainiumProviderIconDiscovery, Invoke-WintainiumProviderReleaseDiscovery
