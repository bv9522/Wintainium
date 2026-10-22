
function New-OfficialDownloadPageReleaseDiscoveryResult {
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
        OperationId=$OperationId; IsSuccessful=$IsSuccessful; Status=$Status
        Releases=@($Releases); Errors=@($Errors); Warnings=@($Warnings); LogEvents=@($LogEvents)
    }
}

function Get-OfficialDownloadPageSafeUri {
    param([AllowNull()][Uri]$Uri)
    if ($null -eq $Uri -or -not $Uri.IsAbsoluteUri) { return $null }
    # Query strings and fragments can contain credentials, signed URLs, or tracking tokens.
    return $Uri.GetLeftPart([UriPartial]::Path)
}

function New-OfficialDownloadPageDiagnosticEvent {
    param(
        [Parameter(Mandatory)][string]$OperationId,
        [Parameter(Mandatory)][string]$EventName,
        [Parameter(Mandatory)][string]$Message,
        [hashtable]$Context = @{},
        [ValidateSet('Information','Warning','Error')][string]$Severity = 'Information'
    )
    [pscustomobject][ordered]@{
        Timestamp=[DateTimeOffset]::UtcNow; Severity=$Severity; OperationId=$OperationId
        Component='OfficialDownloadPageProvider'; EventName=$EventName; Message=$Message; Context=$Context
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

function Get-OfficialDownloadPageGitHubAssetVerificationEvidence {
    param(
        [Parameter(Mandatory)][Uri]$ArtifactUri,
        [Parameter(Mandatory)][hashtable]$ReleaseCache
    )
    if ($ArtifactUri.Host -notin @('github.com', 'www.github.com')) { return $null }
    $segments = @($ArtifactUri.AbsolutePath.Trim('/').Split('/') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($segments.Count -lt 6 -or $segments[2] -ne 'releases' -or $segments[3] -ne 'download') { return $null }
    $owner=[Uri]::UnescapeDataString($segments[0]); $repository=[Uri]::UnescapeDataString($segments[1]); $tag=[Uri]::UnescapeDataString($segments[4]); $assetPath=($segments[5..($segments.Count-1)] -join '/')
    if ($owner -notmatch '^[A-Za-z0-9_.-]+$' -or $repository -notmatch '^[A-Za-z0-9_.-]+$' -or [string]::IsNullOrWhiteSpace($tag) -or [string]::IsNullOrWhiteSpace($assetPath)) { return $null }
    $apiUri="https://api.github.com/repos/$([Uri]::EscapeDataString($owner))/$([Uri]::EscapeDataString($repository))/releases/tags/$([Uri]::EscapeDataString($tag))"
    if ($ReleaseCache.ContainsKey($apiUri)) { $release=$ReleaseCache[$apiUri] } else {
        try { $release=Invoke-RestMethod -Method Get -Uri $apiUri -Headers @{Accept='application/vnd.github+json'; 'User-Agent'='Wintainium/0.1'} -ErrorAction Stop } catch { $release=[pscustomobject]@{Assets=@()} }
        $ReleaseCache[$apiUri]=$release
    }
    if ($null -eq $release -or -not $release.PSObject.Properties['assets']) { return $null }
    foreach($asset in @($release.assets)) {
        if ($null -eq $asset -or -not $asset.PSObject.Properties['browser_download_url']) { continue }
        if ([string]$asset.browser_download_url -ne $ArtifactUri.AbsoluteUri) { continue }
        if (-not $asset.PSObject.Properties['digest']) { continue }
        $digest=[string]$asset.digest
        if ($digest -match '(?i)^sha256:([0-9a-f]{64})$') { return [pscustomobject][ordered]@{Algorithm='SHA256';Value=$matches[1].ToUpperInvariant();Source='GitHubReleaseAssetDigest'} }
    }
    return $null
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

        # Architecture is an artifact-level property. Do not include the full release text here:
        # unrelated links in the same release section can mention a different architecture
        # and contaminate classification (for example, a 7-Zip x64 link being marked arm64
        # merely because the same release also contains an ARM64 link).
        $architecture=ConvertTo-OfficialDownloadPageArtifactArchitecture "$fileName $label"
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
    $logEvents=[System.Collections.Generic.List[object]]::new()
    $stopwatch=[System.Diagnostics.Stopwatch]::StartNew()

    if ($settings -is [System.Collections.IDictionary] -and $settings.Contains('pageUri')) {
        $pageUri=[string]$settings.pageUri
    }
    elseif ($null -ne $settings -and $settings.PSObject.Properties['pageUri']) {
        $pageUri=[string]$settings.pageUri
    }

    try { $baseUri=[Uri]$pageUri } catch {
        return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'ConfigurationInvalid' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageReleasePageInvalid' 'Official download page setting pageUri must be a valid URI.')
        ) -LogEvents @((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'ReleaseDiscoveryConfigurationRejected' -Message 'The configured page URI could not be parsed.' -Context @{FailureStage='Configuration';Outcome='InvalidPageUri'} -Severity Warning))
    }

    if (-not $baseUri.IsAbsoluteUri -or $baseUri.Scheme -notin @('http','https')) {
        return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'ConfigurationInvalid' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageReleasePageInvalid' 'Official download page setting pageUri must use HTTP or HTTPS.')
        ) -LogEvents @((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'ReleaseDiscoveryConfigurationRejected' -Message 'The configured page URI must use HTTP or HTTPS.' -Context @{FailureStage='Configuration';Outcome='UnsupportedUriScheme'} -Severity Warning))
    }

    $safeRequestedUri=Get-OfficialDownloadPageSafeUri -Uri $baseUri
    $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'ReleaseDiscoveryRequestStarted' -Message 'Official download page retrieval started.' -Context @{RequestedUrl=$safeRequestedUri;FailureStage='Retrieval'}))
    try {
        $response=Invoke-WebRequest -Method Get -Uri $baseUri.AbsoluteUri -MaximumRedirection 5 -TimeoutSec 30 -ErrorAction Stop
        $html=[string]$response.Content
    }
    catch {
        $stopwatch.Stop()
        $exceptionType=$_.Exception.GetType().Name
        $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'ReleaseDiscoveryRetrievalFailed' -Message 'The official download page request failed before HTML could be parsed.' -Context @{RequestedUrl=$safeRequestedUri;FailureStage='Retrieval';ExceptionType=$exceptionType;DurationMilliseconds=[long]$stopwatch.ElapsedMilliseconds} -Severity Warning))
        return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'SourceUnavailable' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageReleaseRequestFailed' "The official download page request failed ($exceptionType). See discovery diagnostics for request context.")
        ) -LogEvents $logEvents.ToArray()
    }

    $finalUri=$baseUri
    try {
        if ($null -ne $response.BaseResponse -and $null -ne $response.BaseResponse.ResponseUri) { $finalUri=[Uri]$response.BaseResponse.ResponseUri }
        elseif ($null -ne $response.BaseResponse -and $response.BaseResponse.RequestMessage -and $response.BaseResponse.RequestMessage.RequestUri) { $finalUri=[Uri]$response.BaseResponse.RequestMessage.RequestUri }
    } catch {}
    $contentType=$null
    try { if ($response.Headers -and $response.Headers['Content-Type']) { $contentType=[string]$response.Headers['Content-Type'] } } catch {}
    $httpStatus=$null
    try { if ($null -ne $response.StatusCode) { $httpStatus=[int]$response.StatusCode } } catch {}
    $safeFinalUri=Get-OfficialDownloadPageSafeUri -Uri $finalUri
    $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'ReleaseDiscoveryResponseReceived' -Message 'The official download page response was received.' -Context @{RequestedUrl=$safeRequestedUri;FinalUrl=$safeFinalUri;HttpStatusCode=$httpStatus;ContentType=$contentType;HtmlLength=$html.Length;FailureStage='Parsing'}))

    if ([string]::IsNullOrWhiteSpace($html)) {
        $stopwatch.Stop()
        $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'ReleaseDiscoveryParsingFailed' -Message 'The page request completed but returned an empty HTML document.' -Context @{RequestedUrl=$safeRequestedUri;FinalUrl=$safeFinalUri;HttpStatusCode=$httpStatus;ContentType=$contentType;HtmlLength=0;FailureStage='Parsing';Outcome='EmptyDocument';DurationMilliseconds=[long]$stopwatch.ElapsedMilliseconds} -Severity Warning))
        return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'UpstreamResponseInvalid' -Errors @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageReleaseContentEmpty' 'The official download page returned an empty HTML document.')
        ) -LogEvents $logEvents.ToArray()
    }

    # Official download pages do not have a universal release-section HTML shape.
    # This trace records what the current parser recognized without dumping HTML.
    $sectionMatches=[regex]::Matches(
        $html,
        '(?is)<h([1-6])\b[^>]*>(.*?)</h\1\s*>|(?:^|>)\s*(Download\s+[^<\r\n]+?\s+v?[0-9]+(?:\.[0-9]+){1,3}\s*\(20[0-9]{2}[-./][0-9]{1,2}[-./][0-9]{1,2}\)[^<\r\n]*?)\s*(?=<|$)',
        [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline
    )
    $downloadLinkMatches=[regex]::Matches($html,'<a\b[^>]*href\s*=\s*["'']([^"'']+)["''][^>]*>',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $downloadArtifactCandidateCount=0
    foreach($linkMatch in $downloadLinkMatches) {
        $href=$linkMatch.Groups[1].Value
        try { $candidateUri=[Uri]::new($baseUri,$href) } catch { continue }
        if ($candidateUri.Scheme -notin @('http','https')) { continue }
        if ([IO.Path]::GetExtension($candidateUri.AbsolutePath).ToLowerInvariant() -in @('.exe','.msi','.zip')) { $downloadArtifactCandidateCount++ }
    }

    $releases=[System.Collections.Generic.List[object]]::new()
    $githubReleaseCache=@{}
    $parsedArtifactCount=0
    for($i=0;$i -lt $sectionMatches.Count;$i++) {
        $section=$sectionMatches[$i]
        $nextStart=if($i+1 -lt $sectionMatches.Count){$sectionMatches[$i+1].Index}else{$html.Length}
        $bodyStart=$section.Index+$section.Length
        if($bodyStart -ge $nextStart){continue}

        $heading = if($section.Groups[2].Success) { $section.Groups[2].Value } else { $section.Groups[3].Value }
        $body=$html.Substring($bodyStart,$nextStart-$bodyStart)
        try {
            $release=ConvertFrom-OfficialDownloadPageReleaseSection -Heading $heading -Body $body -BaseUri $baseUri
            if($null -ne $release){
                foreach($artifact in @($release.Artifacts)){
                    if($null -eq $artifact){continue}
                    $parsedArtifactCount++
                    try{$artifactUri=[Uri]$artifact.Uri}catch{continue}
                    $evidence=Get-OfficialDownloadPageGitHubAssetVerificationEvidence -ArtifactUri $artifactUri -ReleaseCache $githubReleaseCache
                    if($null -ne $evidence){$artifact.Hashes=@($artifact.Hashes)+$evidence}
                }
                [void]$releases.Add($release)
            }
        }
        catch {
            $stopwatch.Stop()
            $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'ReleaseDiscoveryParsingFailed' -Message 'A candidate release section could not be normalized.' -Context @{RequestedUrl=$safeRequestedUri;FinalUrl=$safeFinalUri;SectionCandidateCount=$sectionMatches.Count;DownloadArtifactCandidateCount=$downloadArtifactCandidateCount;ParsedReleaseCount=$releases.Count;FailureStage='Parsing';Outcome='ReleaseNormalizationException';ExceptionType=$_.Exception.GetType().Name;DurationMilliseconds=[long]$stopwatch.ElapsedMilliseconds} -Severity Warning))
            return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $false -Status 'UpstreamResponseInvalid' -Errors @(
                (New-OfficialDownloadPageError 'OfficialDownloadPageReleaseInvalid' 'A candidate release section could not be normalized. See discovery diagnostics for counts and failure stage.')
            ) -LogEvents $logEvents.ToArray()
        }
    }

    $stopwatch.Stop()
    $outcome=if($releases.Count -gt 0){'ReleasesParsed'}elseif($sectionMatches.Count -eq 0){'NoReleaseSectionCandidates'}elseif($downloadArtifactCandidateCount -eq 0){'NoSupportedDownloadLinks'}else{'ReleaseSectionsProducedNoArtifacts'}
    $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'ReleaseDiscoveryParsingCompleted' -Message 'Official download page parsing completed.' -Context @{RequestedUrl=$safeRequestedUri;FinalUrl=$safeFinalUri;HttpStatusCode=$httpStatus;ContentType=$contentType;HtmlLength=$html.Length;SectionCandidateCount=$sectionMatches.Count;DownloadArtifactCandidateCount=$downloadArtifactCandidateCount;ParsedArtifactCount=$parsedArtifactCount;ParsedReleaseCount=$releases.Count;Outcome=$outcome;FailureStage=if($releases.Count -eq 0){'Parsing'}else{'None'};DurationMilliseconds=[long]$stopwatch.ElapsedMilliseconds} -Severity $(if($releases.Count -eq 0){'Warning'}else{'Information'}))

    if($releases.Count -eq 0){
        return New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $true -Status 'NoReleasesFound' -Warnings @(
            (New-OfficialDownloadPageError 'OfficialDownloadPageNoReleaseCandidates' "The page was retrieved, but release discovery produced no releases ($outcome).")
        ) -LogEvents $logEvents.ToArray()
    }

    New-OfficialDownloadPageReleaseDiscoveryResult -OperationId $operationId -IsSuccessful $true -Status 'Success' -Releases $releases.ToArray() -LogEvents $logEvents.ToArray()
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
    $logEvents=[System.Collections.Generic.List[object]]::new()
    $stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
    try {$sourceUri=[Uri]([string]$Request.SourceUri)} catch {
        $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'SourceResolutionRejected' -Message 'The supplied source URL could not be parsed.' -Context @{FailureStage='Configuration';Outcome='InvalidSourceUri'} -Severity Warning))
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceInvalid' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageUriInvalid' 'The supplied source URL is not a valid URI.') @() $logEvents.ToArray()
    }
    if (-not $sourceUri.IsAbsoluteUri -or $sourceUri.Scheme -notin @('http','https')) {
        $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'SourceResolutionRejected' -Message 'Official download page resolution requires HTTP or HTTPS.' -Context @{Host=$sourceUri.Host;FailureStage='Configuration';Outcome='UnsupportedUriScheme'} -Severity Warning))
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceUnsupported' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageSchemeUnsupported' 'Official download page resolution requires HTTP or HTTPS.') @() $logEvents.ToArray()
    }
    $safeSourceUri=Get-OfficialDownloadPageSafeUri -Uri $sourceUri
    if ($sourceUri.Host -ieq 'github.com' -or $sourceUri.Host -ieq 'www.github.com') {
        $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'SourceResolutionDelegated' -Message 'GitHub source URLs are handled by the dedicated GitHub provider.' -Context @{RequestedUrl=$safeSourceUri;Host=$sourceUri.Host;Outcome='DedicatedProviderFallback'} -Severity Information))
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceUnsupported' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageHostUnsupported' 'GitHub sources are resolved by the GitHub provider.') @() $logEvents.ToArray()
    }

    $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'SourceResolutionRequestStarted' -Message 'Official download page source resolution started.' -Context @{RequestedUrl=$safeSourceUri;Host=$sourceUri.Host;FailureStage='Retrieval'}))
    try {$response=Invoke-WebRequest -Method Get -Uri $sourceUri.AbsoluteUri -MaximumRedirection 5 -TimeoutSec 30 -ErrorAction Stop} catch {
        $stopwatch.Stop()
        $exceptionType=$_.Exception.GetType().Name
        $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'SourceResolutionRetrievalFailed' -Message 'The source page request failed before identity metadata could be parsed.' -Context @{RequestedUrl=$safeSourceUri;Host=$sourceUri.Host;FailureStage='Retrieval';ExceptionType=$exceptionType;DurationMilliseconds=[long]$stopwatch.ElapsedMilliseconds} -Severity Warning))
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceUnavailable' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageRequestFailed' "The source page request failed ($exceptionType). See source-resolution diagnostics for request context.") @() $logEvents.ToArray()
    }

    $contentType=''
    if ($response.Headers -and $response.Headers['Content-Type']) {$contentType=[string]$response.Headers['Content-Type']}
    $httpStatus=$null
    try { if ($null -ne $response.StatusCode) { $httpStatus=[int]$response.StatusCode } } catch {}
    $finalUri=$sourceUri
    try {
        if ($null -ne $response.BaseResponse -and $null -ne $response.BaseResponse.ResponseUri) { $finalUri=[Uri]$response.BaseResponse.ResponseUri }
        elseif ($null -ne $response.BaseResponse -and $response.BaseResponse.RequestMessage -and $response.BaseResponse.RequestMessage.RequestUri) { $finalUri=[Uri]$response.BaseResponse.RequestMessage.RequestUri }
    } catch {}
    $safeFinalUri=Get-OfficialDownloadPageSafeUri -Uri $finalUri
    $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'SourceResolutionResponseReceived' -Message 'The source page response was received.' -Context @{RequestedUrl=$safeSourceUri;FinalUrl=$safeFinalUri;Host=$sourceUri.Host;HttpStatusCode=$httpStatus;ContentType=$contentType;FailureStage='IdentityParsing'}))

    if ($contentType -and $contentType -notmatch '(?i)text/html|application/xhtml\+xml') {
        $stopwatch.Stop()
        $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'SourceResolutionRejected' -Message 'The response content type is not supported for official download page resolution.' -Context @{RequestedUrl=$safeSourceUri;FinalUrl=$safeFinalUri;ContentType=$contentType;FailureStage='Validation';Outcome='UnsupportedContentType';DurationMilliseconds=[long]$stopwatch.ElapsedMilliseconds} -Severity Warning))
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceUnsupported' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageContentTypeUnsupported' "Unsupported content type '$contentType'.") @() $logEvents.ToArray()
    }

    $html=[string]$response.Content
    if ([string]::IsNullOrWhiteSpace($html)) {
        $stopwatch.Stop()
        $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'SourceResolutionRejected' -Message 'The source response contained no HTML content.' -Context @{RequestedUrl=$safeSourceUri;FinalUrl=$safeFinalUri;HttpStatusCode=$httpStatus;ContentType=$contentType;FailureStage='IdentityParsing';Outcome='EmptyDocument';DurationMilliseconds=[long]$stopwatch.ElapsedMilliseconds} -Severity Warning))
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceResponseInvalid' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageContentEmpty' 'The source returned an empty HTML document.') @() $logEvents.ToArray()
    }

    $canonical=Get-OfficialDownloadPageCanonicalUri -Html $html -BaseUri $finalUri
    $name=Get-OfficialDownloadPageApplicationName -Html $html
    if ([string]::IsNullOrWhiteSpace($name)) {
        $stopwatch.Stop()
        $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'SourceResolutionRejected' -Message 'The response was retrieved but supported identity metadata did not yield an application name.' -Context @{RequestedUrl=$safeSourceUri;FinalUrl=$safeFinalUri;HttpStatusCode=$httpStatus;ContentType=$contentType;HtmlLength=$html.Length;FailureStage='IdentityParsing';Outcome='ApplicationIdentityMissing';DurationMilliseconds=[long]$stopwatch.ElapsedMilliseconds} -Severity Warning))
        return New-OfficialDownloadPageSourceResolutionResult $operationId $false 'SourceResponseInvalid' $null @(New-OfficialDownloadPageError 'OfficialDownloadPageIdentityMissing' 'The page did not expose a usable application name in supported identity metadata or headings.') @() $logEvents.ToArray()
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
    $stopwatch.Stop()
    $logEvents.Add((New-OfficialDownloadPageDiagnosticEvent -OperationId $operationId -EventName 'SourceResolutionCompleted' -Message 'Official download page source resolution completed.' -Context @{RequestedUrl=$safeSourceUri;FinalUrl=$safeFinalUri;Host=$sourceUri.Host;ApplicationId=$applicationId;ContentType=$contentType;Outcome='Resolved';DurationMilliseconds=[long]$stopwatch.ElapsedMilliseconds}))
    New-OfficialDownloadPageSourceResolutionResult $operationId $true 'Resolved' $source @() @() $logEvents.ToArray()
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
