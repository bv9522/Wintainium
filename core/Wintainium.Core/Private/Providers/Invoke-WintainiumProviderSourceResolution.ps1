function Invoke-WintainiumProviderSourceResolution {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Provider,[Parameter(Mandatory)][object]$Request)

    $operationId=[string]$Request.OperationId
    $logEvents=[System.Collections.Generic.List[object]]::new()
    $baseResult={
        param([bool]$IsSuccessful,[string]$Status,[object]$Source=$null,[object[]]$Errors=@(),[object[]]$Warnings=@())
        [pscustomobject][ordered]@{
            OperationId=$operationId; IsSuccessful=$IsSuccessful; Status=$Status
            Source=$Source; Errors=@($Errors); Warnings=@($Warnings); LogEvents=$logEvents.ToArray()
        }
    }

    if ($Provider.PluginType -ne 'Provider') {
        $error=[pscustomobject]@{Code='SourceResolutionInvalidPluginType';Message='The supplied plugin is not a provider.'}
        return & $baseResult $false 'SourceResolverInternalError' $null @($error) @()
    }

    if ($null -eq $Provider.Capabilities -or -not ($Provider.Capabilities -is [System.Collections.IDictionary]) -or
        -not $Provider.Capabilities.ContainsKey('sourceResolution') -or $Provider.Capabilities.sourceResolution -ne $true) {
        $error=[pscustomobject]@{Code='SourceResolutionCapabilityUnsupported';Message="Provider '$($Provider.PluginId)' does not advertise source resolution capability."}
        return & $baseResult $false 'SourceUnsupported' $null @($error) @()
    }

    if ([string]::IsNullOrWhiteSpace([string]$Request.SourceUri)) {
        $error=[pscustomobject]@{Code='SourceResolutionUriMissing';Message='SourceUri is required.'}
        return & $baseResult $false 'SourceInvalid' $null @($error) @()
    }

    try { $sourceUri=[Uri]([string]$Request.SourceUri) }
    catch {
        $error=[pscustomobject]@{Code='SourceResolutionUriInvalid';Message="SourceUri '$($Request.SourceUri)' is not a valid absolute URI."}
        return & $baseResult $false 'SourceInvalid' $null @($error) @()
    }
    if (-not $sourceUri.IsAbsoluteUri -or $sourceUri.Scheme -notin @('http','https')) {
        $error=[pscustomobject]@{Code='SourceResolutionUriInvalid';Message='SourceUri must be an absolute HTTP or HTTPS URI.'}
        return & $baseResult $false 'SourceInvalid' $null @($error) @()
    }

    if ([string]::IsNullOrWhiteSpace([string]$Provider.EntryPoint) -or [string]::IsNullOrWhiteSpace([string]$Provider.DescriptorPath)) {
        $error=[pscustomobject]@{Code='SourceResolverConfigurationInvalid';Message='Provider source-resolution configuration must include an entry point and descriptor path.'}
        return & $baseResult $false 'SourceResolverInternalError' $null @($error) @()
    }

    $providerDirectory=Split-Path -Path $Provider.DescriptorPath -Parent
    $modulePath=Join-Path -Path $providerDirectory -ChildPath ([IO.Path]::GetFileName([string]$Provider.EntryPoint))
    try { $resolvedModulePath=(Resolve-Path -LiteralPath $modulePath -ErrorAction Stop).Path }
    catch {
        $error=[pscustomobject]@{Code='SourceResolverEntryPointNotFound';Message="Provider entry point '$($Provider.EntryPoint)' was not found."}
        return & $baseResult $false 'SourceResolverInternalError' $null @($error) @()
    }

    try {
        $module=Import-Module -Name $resolvedModulePath -Force -PassThru -ErrorAction Stop
        $commandName="$($module.Name)\Invoke-WintainiumProviderSourceResolution"
        $command=Get-Command -Name $commandName -CommandType Function -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            $error=[pscustomobject]@{Code='SourceResolverOperationNotFound';Message="Provider '$($Provider.PluginId)' does not export Invoke-WintainiumProviderSourceResolution."}
            return & $baseResult $false 'SourceResolverInternalError' $null @($error) @()
        }
        $resolverResult=& $command -Request $Request
    }
    catch {
        $error=[pscustomobject]@{Code='SourceResolverInternalError';Message=$_.Exception.Message}
        return & $baseResult $false 'SourceResolverInternalError' $null @($error) @()
    }

    if ($null -eq $resolverResult -or @($resolverResult).Count -ne 1) {
        $error=[pscustomobject]@{Code='SourceResolutionResultInvalid';Message='Source resolver must return exactly one structured result object.'}
        return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
    }

    foreach ($requiredProperty in @('OperationId','IsSuccessful','Status','Source','Errors','Warnings','LogEvents')) {
        if (-not $resolverResult.PSObject.Properties[$requiredProperty]) {
            $error=[pscustomobject]@{Code='SourceResolutionResultInvalid';Message="Source resolver result is missing required property '$requiredProperty'."}
            return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
        }
    }

    if ([string]$resolverResult.OperationId -ne $operationId) {
        $error=[pscustomobject]@{Code='SourceResolutionOperationIdMismatch';Message='Source resolver result OperationId does not match the Core request OperationId.'}
        return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
    }

    foreach ($event in @($resolverResult.LogEvents)) {
        if ($null -ne $event -and $event.PSObject.Properties['OperationId'] -and [string]$event.OperationId -ne $operationId) {
            $error=[pscustomobject]@{Code='SourceResolutionLogCorrelationInvalid';Message='Source resolver log event OperationId does not match the Core request OperationId.'}
            return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
        }
        $logEvents.Add($event)
    }

    foreach ($diagnostic in @($resolverResult.Errors)+@($resolverResult.Warnings)) {
        if ($null -ne $diagnostic -and $diagnostic.PSObject.Properties['OperationId'] -and [string]$diagnostic.OperationId -ne $operationId) {
            $error=[pscustomobject]@{Code='SourceResolutionDiagnosticCorrelationInvalid';Message='Source resolver diagnostic OperationId does not match the Core request OperationId.'}
            return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$resolverResult.Status)) {
        $error=[pscustomobject]@{Code='SourceResolutionResultInvalid';Message='Source resolver result Status cannot be empty.'}
        return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
    }

    if ([bool]$resolverResult.IsSuccessful) {
        if ($null -eq $resolverResult.Source) {
            $error=[pscustomobject]@{Code='SourceResolutionSourceMissing';Message='A successful source-resolution result must contain normalized Source facts.'}
            return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
        }
        foreach ($requiredSourceProperty in @('ApplicationId','Name','CanonicalUri','ProviderId','ProviderContractVersion','ProviderSettings')) {
            if (-not $resolverResult.Source.PSObject.Properties[$requiredSourceProperty]) {
                $error=[pscustomobject]@{Code='SourceResolutionSourceInvalid';Message="Resolved Source is missing required property '$requiredSourceProperty'."}
                return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
            }
        }
    }

    $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $operationId -Component 'SourceResolution' -EventName 'SourceResolutionCompleted' -Message 'Source resolution completed.' -Context @{ProviderId=$Provider.PluginId;Status=[string]$resolverResult.Status}))
    & $baseResult ([bool]$resolverResult.IsSuccessful) ([string]$resolverResult.Status) $resolverResult.Source @($resolverResult.Errors) @($resolverResult.Warnings)
}
