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
    foreach ($name in $Names) {
        $escaped=[regex]::Escape($name)
        foreach ($pattern in @(
            '<meta\s+[^>]*name\s*=\s*["'']' + $escaped + '["''][^>]*content\s*=\s*["'']([^"'']+)["''][^>]*>',
            '<meta\s+[^>]*property\s*=\s*["'']' + $escaped + '["''][^>]*content\s*=\s*["'']([^"'']+)["''][^>]*>',
            '<meta\s+[^>]*content\s*=\s*["'']([^"'']+)["''][^>]*name\s*=\s*["'']' + $escaped + '["''][^>]*>',
            '<meta\s+[^>]*content\s*=\s*["'']([^"'']+)["''][^>]*property\s*=\s*["'']' + $escaped + '["''][^>]*>'
        )) {
            $match=[regex]::Match($Html,$pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($match.Success) {
                $value=ConvertFrom-OfficialDownloadPageHtmlText $match.Groups[1].Value
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
    $match=[regex]::Match($Html,'<link\s+[^>]*rel\s*=\s*["'']canonical["''][^>]*href\s*=\s*["'']([^"'']+)["''][^>]*>',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) { return $BaseUri.AbsoluteUri }
    try {$uri=[Uri]::new($BaseUri,$match.Groups[1].Value);if ($uri.Scheme -in @('http','https')) {return $uri.AbsoluteUri}} catch {}
    return $BaseUri.AbsoluteUri
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
        (Get-OfficialDownloadPageMetaValue -Html $Html -Names @('og:site_name','og:title')),
        (Get-OfficialDownloadPageHeading -Html $Html),
        (Get-OfficialDownloadPageTitle -Html $Html)
    )) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            $name=$candidate -replace '\s*[|–—-]\s*(download|downloads|official download page)\s*$',''
            if ($name.Trim()) {return $name.Trim()}
        }
    }
    return $null
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
    try {$response=Invoke-WebRequest -Method Get -Uri $sourceUri.AbsoluteUri -MaximumRedirection 5 -ErrorAction Stop} catch {
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
    $publisher=Get-OfficialDownloadPageMetaValue -Html $html -Names @('publisher','og:site_name')
    $source=[pscustomobject][ordered]@{
        ApplicationId=$applicationId;Name=$name;Publisher=$publisher;Homepage=$canonical;CanonicalUri=$canonical
        ProviderId='Wintainium.provider.official-download-page';ProviderContractVersion='1'
        ProviderSettings=[ordered]@{pageUri=$canonical}
        SourceContext=[pscustomobject][ordered]@{sourceFamily='official-download-page';contentType=if($contentType){$contentType}else{'text/html'}}
    }
    New-OfficialDownloadPageSourceResolutionResult $operationId $true 'Resolved' $source
}
Export-ModuleMember -Function Invoke-WintainiumProviderSourceResolution
