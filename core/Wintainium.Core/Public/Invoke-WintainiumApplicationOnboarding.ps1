function Invoke-WintainiumApplicationOnboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SourceUri,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ManifestRoot,
        [Parameter(Mandatory)][ValidateNotNull()][psobject]$Policy,
        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),
        [string]$OperationId
    )

    $resolvedOperationId = [guid]::Empty
    if ([string]::IsNullOrWhiteSpace($OperationId)) {
        $resolvedOperationId = [guid]::NewGuid()
    }
    elseif (-not [guid]::TryParse($OperationId, [ref]$resolvedOperationId)) {
        return [pscustomobject][ordered]@{
            OperationId=$OperationId; IsSuccessful=$false; Status='SourceInvalid'
            SourceResolution=$null; ApplicationDefinition=$null; ManifestPath=$null
            Errors=@([pscustomobject][ordered]@{Code='OperationIdInvalid';Path='$.OperationId';Message='OperationId must be a valid GUID.'})
            Warnings=@(); LogEvents=@()
        }
    }
    $resolvedOperationId=$resolvedOperationId.ToString()
    $errors=[System.Collections.Generic.List[object]]::new()
    $warnings=[System.Collections.Generic.List[object]]::new()
    $logEvents=[System.Collections.Generic.List[object]]::new()

    try { $sourceUriObject=[Uri]$SourceUri }
    catch {
        $errors.Add([pscustomobject][ordered]@{Code='SourceResolutionUriInvalid';Path='$.SourceUri';Message="SourceUri '$SourceUri' is not a valid absolute URI."})
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status='SourceInvalid';SourceResolution=$null;ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=@();LogEvents=@()}
    }
    if (-not $sourceUriObject.IsAbsoluteUri -or $sourceUriObject.Scheme -notin @('http','https')) {
        $errors.Add([pscustomobject][ordered]@{Code='SourceResolutionUriInvalid';Path='$.SourceUri';Message='SourceUri must be an absolute HTTP or HTTPS URI.'})
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status='SourceInvalid';SourceResolution=$null;ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=@();LogEvents=@()}
    }

    $registry=Get-WintainiumPluginRegistry -PluginRoot $PluginRoot
    foreach($descriptorError in @($registry.DescriptorErrors)) {
        $warnings.Add([pscustomobject][ordered]@{Code='PluginDescriptorIgnored';Message='An invalid plugin descriptor was ignored by the registry.';Detail=$descriptorError})
    }

    $capableProviders=@($registry.Plugins | Where-Object {
        $_.PluginType -eq 'Provider' -and
        $_.Capabilities -is [System.Collections.IDictionary] -and
        $_.Capabilities.ContainsKey('sourceResolution') -and
        $_.Capabilities.sourceResolution -eq $true
    } | Sort-Object DescriptorPath)

    if($capableProviders.Count -eq 0) {
        $errors.Add([pscustomobject][ordered]@{Code='SourceResolutionCapabilityUnavailable';Path='$.SourceUri';Message='No registered provider advertises source resolution capability.'})
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status='SourceUnsupported';SourceResolution=$null;ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=@()}
    }

    $successful=[System.Collections.Generic.List[object]]::new()
    $failures=[System.Collections.Generic.List[object]]::new()
    foreach($provider in $capableProviders) {
        $request=[pscustomobject][ordered]@{OperationId=$resolvedOperationId;SourceUri=$SourceUri;ResolutionContext=$null}
        $resolution=Invoke-WintainiumCoreProviderSourceResolution -Provider $provider -Request $request
        foreach($event in @($resolution.LogEvents)){$logEvents.Add($event)}
        foreach($warning in @($resolution.Warnings)){$warnings.Add($warning)}
        if([bool]$resolution.IsSuccessful){$successful.Add([pscustomobject]@{Provider=$provider;Result=$resolution})}
        else {
            $failures.Add($resolution)
            foreach($errorRecord in @($resolution.Errors)){$errors.Add($errorRecord)}
        }
    }

    if($successful.Count -eq 0) {
        $status='SourceUnsupported'
        foreach($candidate in @('SourceAmbiguous','SourceUnavailable','AuthenticationRequired','InteractiveResolutionRequired','SourceResponseInvalid')) {
            if(@($failures | Where-Object Status -eq $candidate).Count -gt 0){$status=$candidate;break}
        }
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status=$status;SourceResolution=if($failures.Count -eq 1){$failures[0]}else{$null};ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray()}
    }

    if($successful.Count -gt 1) {
        $errors.Add([pscustomobject][ordered]@{Code='SourceResolutionAmbiguous';Path='$.SourceUri';Message='Multiple source-resolution providers successfully resolved the supplied source URI.'})
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status='SourceAmbiguous';SourceResolution=$null;ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray()}
    }

    $sourceResolution=$successful[0].Result
    $normalization=New-WintainiumApplicationDefinitionFromSource -Source $sourceResolution.Source -Policy $Policy -OperationId $resolvedOperationId
    foreach($warning in @($normalization.Warnings)){$warnings.Add($warning)}
    foreach($errorRecord in @($normalization.Errors)){$errors.Add($errorRecord)}
    foreach($event in @($normalization.LogEvents)){$logEvents.Add($event)}

    if(-not $normalization.IsSuccessful) {
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status=[string]$normalization.Status;SourceResolution=$sourceResolution;ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray()}
    }

    try {
        $manifestPath=Set-WintainiumApplicationDefinition -ApplicationDefinition $normalization.ApplicationDefinition -ManifestRoot $ManifestRoot -SchemaPath $SchemaPath
    }
    catch {
        $errors.Add([pscustomobject][ordered]@{Code='ApplicationDefinitionPersistenceFailed';Path='$.ManifestRoot';Message=$_.Exception.Message})
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status='ApplicationDefinitionPersistenceFailed';SourceResolution=$sourceResolution;ApplicationDefinition=$normalization.ApplicationDefinition;ManifestPath=$null;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray()}
    }

    $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $resolvedOperationId -Component 'Core' -EventName 'ApplicationOnboardingCompleted' -Message 'Application source was resolved, normalized, and persisted.' -Context @{ApplicationId=[string]$normalization.ApplicationDefinition.Id;ManifestPath=$manifestPath}))
    [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$true;Status='Resolved';SourceResolution=$sourceResolution;ApplicationDefinition=$normalization.ApplicationDefinition;ManifestPath=$manifestPath;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray()}
}
