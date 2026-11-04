function Invoke-WintainiumCoreProviderSourceResolution {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Provider,[Parameter(Mandatory)][object]$Request)

    $operationId=[string]$Request.OperationId
    $logEvents=[System.Collections.Generic.List[object]]::new()
    $sourceHost=$null
    try {
        $candidateSourceUri=[Uri]([string]$Request.SourceUri)
        if ($candidateSourceUri.IsAbsoluteUri -and $candidateSourceUri.Scheme -in @('http','https')) {
            $sourceHost=$candidateSourceUri.DnsSafeHost.ToLowerInvariant()
        }
    } catch {}
    $baseResult={
        param([bool]$IsSuccessful,[string]$Status,[object]$Source=$null,[object[]]$Errors=@(),[object[]]$Warnings=@())
        if (-not $IsSuccessful) {
            $context=@{Stage='SourceIdentification';Status=$Status}
            if ($Provider.PSObject.Properties['PluginId'] -and -not [string]::IsNullOrWhiteSpace([string]$Provider.PluginId)) {
                $context.ProviderId=[string]$Provider.PluginId
            }
            if (-not [string]::IsNullOrWhiteSpace($sourceHost)) {
                $context.Host=$sourceHost
            }
            if (@($Errors).Count -gt 0 -and $Errors[0].PSObject.Properties['Code']) {
                $context.ErrorCode=[string]$Errors[0].Code
            }
            $logEvents.Add((New-WintainiumLogEvent -Severity Warning -OperationId $operationId -Component 'SourceIdentification' -EventName 'ProviderSourceResolutionFailed' -Message 'Provider source-identification attempt failed.' -Context $context))
        }
        [pscustomobject][ordered]@{
            OperationId=$operationId; ProviderId=[string]$Provider.PluginId
            IsSuccessful=$IsSuccessful; Status=$Status
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
        $error=[pscustomobject]@{Code='SourceResolutionUriInvalid';Message='SourceUri could not be parsed as an absolute URI.'}
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
        # Bind invocation to the exact validated module path. Module-name lookup can
        # select a different provider copy when two plugins use the same module name.
        $module=Get-Module | Where-Object {
            $_.Path -and ((Resolve-Path -LiteralPath $_.Path -ErrorAction SilentlyContinue).Path -eq $resolvedModulePath)
        } | Select-Object -First 1

        if ($null -ne $module -and
            -not $module.ExportedFunctions.ContainsKey('Invoke-WintainiumProviderSourceResolution')) {
            Remove-Module -ModuleInfo $module -Force -ErrorAction Stop
            $module=$null
        }

        if ($null -eq $module) {
            $moduleName=[IO.Path]::GetFileNameWithoutExtension($resolvedModulePath)
            foreach ($loadedModule in @(Get-Module | Where-Object { $_.Name -eq $moduleName })) {
                Remove-Module -ModuleInfo $loadedModule -Force -ErrorAction Stop
            }

            $module=Import-Module -Name $resolvedModulePath -PassThru -Force -ErrorAction Stop |
                Where-Object { $_.Path -and ((Resolve-Path -LiteralPath $_.Path -ErrorAction SilentlyContinue).Path -eq $resolvedModulePath) } |
                Select-Object -First 1
        }

        $command=$null
        if ($null -ne $module) {
            $command=$module.ExportedFunctions['Invoke-WintainiumProviderSourceResolution']
        }
        if ($null -eq $command) {
            $error=[pscustomobject]@{Code='SourceResolverOperationNotFound';Message="Provider '$($Provider.PluginId)' does not export Invoke-WintainiumProviderSourceResolution."}
            return & $baseResult $false 'SourceResolverInternalError' $null @($error) @()
        }
        $resolverResult=& $command -Request $Request
    }
    catch {
        $exceptionType=$_.Exception.GetType().Name
        $error=[pscustomobject]@{Code='SourceResolverInternalError';Message="Source resolver execution failed ($exceptionType). See source-resolution diagnostics for the failure stage."}
        $logEvents.Add((New-WintainiumLogEvent -Severity Error -OperationId $operationId -Component 'SourceIdentification' -EventName 'ProviderSourceResolutionExecutionFailed' -Message 'Provider source resolver execution failed.' -Context @{ErrorCode=$error.Code;ExceptionType=$exceptionType;Host=$sourceHost}))
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

    if ($resolverResult.IsSuccessful -isnot [bool]) {
        $error=[pscustomobject]@{Code='SourceResolutionResultInvalid';Message='Source resolver result IsSuccessful must be a Boolean value.'}
        return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
    }

    if ([string]::IsNullOrWhiteSpace([string]$resolverResult.Status)) {
        $error=[pscustomobject]@{Code='SourceResolutionResultInvalid';Message='Source resolver result Status cannot be empty.'}
        return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
    }

    if ([bool]$resolverResult.IsSuccessful) {
        if ([string]$resolverResult.Status -ne 'Resolved') {
            $error=[pscustomobject]@{Code='SourceResolutionStatusInvalid';Message="A successful source-resolution result must use status 'Resolved'."}
            return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
        }
        if ($null -eq $resolverResult.Source) {
            $error=[pscustomobject]@{Code='SourceResolutionSourceMissing';Message='A successful source-resolution result must contain normalized Source facts.'}
            return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
        }
        foreach ($requiredSourceProperty in @('ApplicationId','Name','CanonicalUri','ProviderId','ProviderContractVersion','ProviderSettings')) {
            if (-not $resolverResult.Source.PSObject.Properties[$requiredSourceProperty] -or
                $null -eq $resolverResult.Source.$requiredSourceProperty -or
                [string]::IsNullOrWhiteSpace([string]$resolverResult.Source.$requiredSourceProperty)) {
                $error=[pscustomobject]@{Code='SourceResolutionSourceInvalid';Message="Resolved Source is missing or has an empty required property '$requiredSourceProperty'."}
                return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
            }
        }

        if ($resolverResult.Source.PSObject.Properties['SourceContext'] -and $null -ne $resolverResult.Source.SourceContext -and
            $resolverResult.Source.SourceContext -isnot [System.Collections.IDictionary] -and
            $resolverResult.Source.SourceContext -isnot [System.Management.Automation.PSCustomObject]) {
            $error=[pscustomobject]@{Code='SourceResolutionSourceContextInvalid';Message='Resolved SourceContext must be a JSON object (dictionary or PSCustomObject) when supplied.'}
            return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
        }

        if ([string]$resolverResult.Source.ProviderId -ine [string]$Provider.PluginId) {
            $error=[pscustomobject]@{Code='SourceResolutionProviderIdentityMismatch';Message='Resolved Source ProviderId must match the provider selected by Core.'}
            return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
        }
        if ([string]$resolverResult.Source.ProviderContractVersion -notin @($Provider.ContractVersions)) {
            $error=[pscustomobject]@{Code='SourceResolutionProviderContractMismatch';Message='Resolved Source ProviderContractVersion must be advertised by the selected provider descriptor.'}
            return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
        }

        $canonicalUri=$null
        if (-not [Uri]::TryCreate([string]$resolverResult.Source.CanonicalUri,[UriKind]::Absolute,[ref]$canonicalUri) -or
            $canonicalUri.Scheme -notin @('http','https')) {
            $error=[pscustomobject]@{Code='SourceResolutionCanonicalUriInvalid';Message='Resolved Source CanonicalUri must be an absolute HTTP or HTTPS URI.'}
            return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
        }
    }
    elseif ([string]$resolverResult.Status -eq 'Resolved' -or $null -ne $resolverResult.Source) {
        $error=[pscustomobject]@{Code='SourceResolutionFailureContainsSource';Message='A failed source-resolution result must not contain a resolved Source or use status Resolved.'}
        return & $baseResult $false 'SourceResolutionResultInvalid' $null @($error) @()
    }

    if ([bool]$resolverResult.IsSuccessful) {
        $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $operationId -Component 'SourceIdentification' -EventName 'SourceResolutionCompleted' -Message 'Provider source identification completed.' -Context @{ProviderId=$Provider.PluginId;Status=[string]$resolverResult.Status;Stage='SourceIdentification';Host=$sourceHost}))
    }
    & $baseResult ([bool]$resolverResult.IsSuccessful) ([string]$resolverResult.Status) $resolverResult.Source @($resolverResult.Errors) @($resolverResult.Warnings)
}
