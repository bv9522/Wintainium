function Invoke-WintainiumApplicationOnboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SourceUri,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ManifestRoot,
        [Parameter(DontShow)][AllowNull()][psobject]$Policy,
        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),
        [string]$OperationId
    )

    $stages = [System.Collections.Generic.List[object]]::new()
    $addStage = {
        param([int]$Sequence, [string]$Name, [string]$Status, [bool]$IsSuccessful, [string]$ReasonCode, [string]$Reason)
        $stages.Add([pscustomobject][ordered]@{
            Sequence=$Sequence; Name=$Name; Status=$Status; IsSuccessful=$IsSuccessful
            ReasonCode=$ReasonCode; Reason=$Reason
        })
    }

    $resolvedOperationId = [guid]::Empty
    if ([string]::IsNullOrWhiteSpace($OperationId)) {
        $resolvedOperationId = [guid]::NewGuid()
    }
    elseif (-not [guid]::TryParse($OperationId, [ref]$resolvedOperationId)) {
        return [pscustomobject][ordered]@{
            OperationId=$OperationId; IsSuccessful=$false; Status='SourceInvalid'
            SourceResolution=$null; ApplicationDefinition=$null; ManifestPath=$null
            Errors=@([pscustomobject][ordered]@{Code='OperationIdInvalid';Path='$.OperationId';Message='OperationId must be a valid GUID.'})
            Warnings=@(); LogEvents=@(); Stages=@([pscustomobject][ordered]@{Sequence=1;Name='InputValidation';Status='Failed';IsSuccessful=$false;ReasonCode='OperationIdInvalid';Reason='OperationId must be a valid GUID.'})
        }
    }
    $resolvedOperationId=$resolvedOperationId.ToString()
    $errors=[System.Collections.Generic.List[object]]::new()
    $warnings=[System.Collections.Generic.List[object]]::new()
    $logEvents=[System.Collections.Generic.List[object]]::new()

    try { $sourceUriObject=[Uri]$SourceUri }
    catch {
        $errors.Add([pscustomobject][ordered]@{Code='SourceResolutionUriInvalid';Path='$.SourceUri';Message="SourceUri '$SourceUri' is not a valid absolute URI."})
        & $addStage 1 'InputValidation' 'Failed' $false 'SourceResolutionUriInvalid' 'SourceUri is not a valid absolute URI.'
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status='SourceInvalid';SourceResolution=$null;ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=@();LogEvents=@();Stages=$stages.ToArray()}
    }
    if (-not $sourceUriObject.IsAbsoluteUri -or $sourceUriObject.Scheme -notin @('http','https')) {
        $errors.Add([pscustomobject][ordered]@{Code='SourceResolutionUriInvalid';Path='$.SourceUri';Message='SourceUri must be an absolute HTTP or HTTPS URI.'})
        & $addStage 1 'InputValidation' 'Failed' $false 'SourceResolutionUriInvalid' 'SourceUri must be an absolute HTTP or HTTPS URI.'
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status='SourceInvalid';SourceResolution=$null;ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=@();LogEvents=@();Stages=$stages.ToArray()}
    }

    & $addStage 1 'InputValidation' 'Completed' $true $null 'Operation ID and absolute HTTP/HTTPS source URI are valid.'
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
        & $addStage 2 'SourceResolution' 'Failed' $false 'SourceResolutionCapabilityUnavailable' 'No registered provider advertises source resolution capability.'
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status='SourceUnsupported';SourceResolution=$null;ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=@();Stages=$stages.ToArray()}
    }

    $successful=[System.Collections.Generic.List[object]]::new()
    $failures=[System.Collections.Generic.List[object]]::new()
    foreach($provider in $capableProviders) {
        $request=[pscustomobject][ordered]@{OperationId=$resolvedOperationId;SourceUri=$SourceUri;ResolutionContext=$null}
        $resolution=Invoke-WintainiumCoreProviderSourceResolution -Provider $provider -Request $request
        if([bool]$resolution.IsSuccessful){$successful.Add([pscustomobject]@{Provider=$provider;Result=$resolution})}
        else {
            $failures.Add($resolution)
            foreach($errorRecord in @($resolution.Errors)){$errors.Add($errorRecord)}
        }
    }

    if($successful.Count -eq 0) {
        foreach($failure in $failures) {
            foreach($event in @($failure.LogEvents)){$logEvents.Add($event)}
            foreach($warning in @($failure.Warnings)){$warnings.Add($warning)}
        }

        $status='SourceUnsupported'
        foreach($candidate in @('SourceAmbiguous','SourceUnavailable','AuthenticationRequired','InteractiveResolutionRequired','SourceResponseInvalid','SourceResolutionResultInvalid','SourceResolverInternalError')) {
            if(@($failures | Where-Object Status -eq $candidate).Count -gt 0){$status=$candidate;break}
        }
        # The stage explanation must describe the resolver outcome that determined
        # the operation's terminal status, not the first provider that declined.
        # Earlier capability refusals remain available in Errors and LogEvents.
        $primaryFailure = $failures | Where-Object { [string]$_.Status -eq $status } | Select-Object -First 1
        $primaryFailureError = if ($null -ne $primaryFailure -and @($primaryFailure.Errors).Count -gt 0) {
            @($primaryFailure.Errors)[0]
        } else {
            $null
        }
        $failureCode = if ($null -ne $primaryFailureError) { [string]$primaryFailureError.Code } elseif ($errors.Count -gt 0) { [string]$errors[0].Code } else { $status }
        $failureReason = if ($null -ne $primaryFailureError) { [string]$primaryFailureError.Message } elseif ($errors.Count -gt 0) { [string]$errors[0].Message } else { 'No capable provider resolved the source URI.' }
        & $addStage 2 'SourceResolution' 'Failed' $false $failureCode $failureReason
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status=$status;SourceResolution=if($failures.Count -eq 1){$failures[0]}else{$null};ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray();Stages=$stages.ToArray()}
    }

    # A successful resolution makes ordinary unsupported/invalid responses
    # from other capable providers expected declines. Keep diagnostics from the
    # successful resolver and retain non-decline failures as warnings so genuine
    # provider faults are not hidden by another provider's success.
    $errors.Clear()
    foreach($resolved in $successful) {
        foreach($event in @($resolved.Result.LogEvents)){$logEvents.Add($event)}
        foreach($warning in @($resolved.Result.Warnings)){$warnings.Add($warning)}
    }
    foreach($failure in $failures | Where-Object { [string]$_.Status -notin @('SourceUnsupported','SourceInvalid') }) {
        foreach($event in @($failure.LogEvents)){$logEvents.Add($event)}
        foreach($warning in @($failure.Warnings)){$warnings.Add($warning)}
        foreach($failureError in @($failure.Errors)) {
            $warnings.Add([pscustomobject][ordered]@{
                Code='SourceResolverAttemptFailed'
                Message='A source resolver failed while another provider successfully resolved the source.'
                Status=[string]$failure.Status
                Detail=$failureError
            })
        }
    }

    if($successful.Count -gt 1) {
        $errors.Add([pscustomobject][ordered]@{Code='SourceResolutionAmbiguous';Path='$.SourceUri';Message='Multiple source-resolution providers successfully resolved the supplied source URI.'})
        & $addStage 2 'SourceResolution' 'Failed' $false 'SourceResolutionAmbiguous' 'Multiple source-resolution providers resolved the supplied source URI.'
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status='SourceAmbiguous';SourceResolution=$null;ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray();Stages=$stages.ToArray()}
    }

    & $addStage 2 'SourceResolution' 'Completed' $true $null 'Exactly one provider resolved the source URI.'
    $sourceResolution=$successful[0].Result
    $sourceProvider=$successful[0].Provider
    $automaticIconUri=$null

    if ($sourceProvider.Capabilities -is [System.Collections.IDictionary] -and
        $sourceProvider.Capabilities.ContainsKey('iconDiscovery') -and
        $sourceProvider.Capabilities.iconDiscovery -eq $true) {
        $iconRequest=[pscustomobject][ordered]@{
            OperationId=$resolvedOperationId
            Source=$sourceResolution.Source
        }
        $iconResolution=Invoke-WintainiumCoreProviderIconDiscovery -Provider $sourceProvider -Request $iconRequest
        if ($iconResolution.IsSuccessful -and -not [string]::IsNullOrWhiteSpace([string]$iconResolution.IconUri)) {
            $automaticIconUri=[string]$iconResolution.IconUri
        }
        elseif ([string]$iconResolution.Status -ne 'NoTrustedIcon' -and [string]$iconResolution.Status -ne 'IconDiscoveryUnsupported') {
            $warnings.Add([pscustomobject][ordered]@{
                Code='IconDiscoveryUnavailable'
                Message='Wintainium could not obtain a trusted automatic application icon during onboarding.'
                Detail=@($iconResolution.Errors)
            })
        }
    }

    if ($null -eq $Policy) {
        $policyResolution = Get-WintainiumDefaultApplicationPolicy -PluginRegistry $registry -ApplicationName ([string]$sourceResolution.Source.Name)
        foreach ($policyError in @($policyResolution.Errors)) { $errors.Add($policyError) }
        if (-not $policyResolution.IsSuccessful) {
            $policyCode = if ($policyResolution.Errors.Count -gt 0) { [string]$policyResolution.Errors[0].Code } else { [string]$policyResolution.Status }
            $policyReason = if ($policyResolution.Errors.Count -gt 0) { [string]$policyResolution.Errors[0].Message } else { 'Core could not resolve an onboarding policy.' }
            & $addStage 3 'PolicyResolution' 'Failed' $false $policyCode $policyReason
            return [pscustomobject][ordered]@{
                OperationId=$resolvedOperationId
                IsSuccessful=$false
                Status=[string]$policyResolution.Status
                SourceResolution=$sourceResolution
                ApplicationDefinition=$null
                ManifestPath=$null
                Errors=$errors.ToArray()
                Warnings=$warnings.ToArray()
                LogEvents=$logEvents.ToArray()
                Stages=$stages.ToArray()
            }
        }
        & $addStage 3 'PolicyResolution' 'Completed' $true $null 'Core resolved the default application policy.'
        $Policy = $policyResolution.Policy
    }
    else {
        & $addStage 3 'PolicyResolution' 'Skipped' $true 'CallerProvidedPolicy' 'The caller supplied an application policy; default policy resolution was not needed.'
    }

    $normalization=New-WintainiumApplicationDefinitionFromSource -Source $sourceResolution.Source -Policy $Policy -OperationId $resolvedOperationId -AutomaticIconUri $automaticIconUri -SubmittedUri $SourceUri
    foreach($warning in @($normalization.Warnings)){$warnings.Add($warning)}
    foreach($errorRecord in @($normalization.Errors)){$errors.Add($errorRecord)}
    foreach($event in @($normalization.LogEvents)){$logEvents.Add($event)}

    if(-not $normalization.IsSuccessful) {
        $normalizationCode = if ($normalization.Errors.Count -gt 0) { [string]$normalization.Errors[0].Code } else { [string]$normalization.Status }
        $normalizationReason = if ($normalization.Errors.Count -gt 0) { [string]$normalization.Errors[0].Message } else { 'The source could not be normalized into a valid application definition.' }
        & $addStage 4 'DefinitionNormalization' 'Failed' $false $normalizationCode $normalizationReason
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status=[string]$normalization.Status;SourceResolution=$sourceResolution;ApplicationDefinition=$null;ManifestPath=$null;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray();Stages=$stages.ToArray()}
    }
    # Re-onboarding the same application refreshes source-derived metadata, but must
    # not reset user-confirmed reconciliation identity rules to the default policy.
    # Preserve those settings only when the existing and newly resolved definitions
    # still declare the same reconciliation plugin and contract.
    $existingManifestPath = Join-Path -Path $ManifestRoot -ChildPath ("$([string]$normalization.ApplicationDefinition.id).wintainium.json")
    if (Test-Path -LiteralPath $existingManifestPath -PathType Leaf) {
        try {
            $existingManifest = Get-Content -LiteralPath $existingManifestPath -Raw -Encoding utf8 -ErrorAction Stop |
                ConvertFrom-Json -AsHashtable -Depth 100 -ErrorAction Stop
            # User-confirmed aliases are Core/user-owned identity facts. Preserve them
            # independently from provider suggestions whenever the same application is
            # re-onboarded. Legacy manifests did not record provenance, so their aliases
            # are conservatively migrated as confirmed rather than discarded.
            $hasConfirmedAliasField = $existingManifest.ContainsKey('userConfirmedAliases')
            $preservedAliasValues = if ($hasConfirmedAliasField) {
                @($existingManifest['userConfirmedAliases'])
            }
            else {
                @($existingManifest['aliases'])
            }
            $confirmedAliases = [System.Collections.Generic.List[string]]::new()
            foreach ($aliasValue in $preservedAliasValues) {
                if ($aliasValue -isnot [string] -or [string]::IsNullOrWhiteSpace($aliasValue)) { continue }
                $normalizedAlias = $aliasValue.Trim()
                if ($normalizedAlias -ieq [string]$normalization.ApplicationDefinition.name) { continue }
                $duplicate = $false
                foreach ($existingAlias in $confirmedAliases) {
                    if ($existingAlias -ieq $normalizedAlias) { $duplicate = $true; break }
                }
                if (-not $duplicate) { $confirmedAliases.Add($normalizedAlias) }
            }

            if ($confirmedAliases.Count -gt 0) {
                $providerAliases = [System.Collections.Generic.List[string]]::new()
                foreach ($providerAlias in @($normalization.ApplicationDefinition.aliases)) {
                    $isConfirmed = $false
                    foreach ($confirmedAlias in $confirmedAliases) {
                        if ([string]$providerAlias -ieq $confirmedAlias) { $isConfirmed = $true; break }
                    }
                    if (-not $isConfirmed) { $providerAliases.Add([string]$providerAlias) }
                }
                if ($providerAliases.Count -gt 0) {
                    $normalization.ApplicationDefinition.aliases = $providerAliases.ToArray()
                }
                else {
                    $normalization.ApplicationDefinition.PSObject.Properties.Remove('aliases')
                }
                $normalization.ApplicationDefinition | Add-Member -NotePropertyName userConfirmedAliases -NotePropertyValue $confirmedAliases.ToArray() -Force

                $eventName = if ($hasConfirmedAliasField) { 'ExistingUserConfirmedAliasesPreserved' } else { 'LegacyAliasesMigratedToUserConfirmed' }
                $eventMessage = if ($hasConfirmedAliasField) {
                    'Re-onboarding preserved user-confirmed identity aliases independently from provider-suggested aliases.'
                }
                else {
                    'Re-onboarding conservatively migrated legacy aliases into the user-confirmed alias collection because their original provenance was not recorded.'
                }
                $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $resolvedOperationId -Component 'Core' -EventName $eventName -Message $eventMessage -Context @{ApplicationId=[string]$normalization.ApplicationDefinition.id;AliasCount=$confirmedAliases.Count}))
            }

            $existingReconciliation = $existingManifest['reconciliation']
            $newReconciliation = $normalization.ApplicationDefinition.reconciliation
            if ($existingReconciliation -is [System.Collections.IDictionary] -and
                $null -ne $newReconciliation -and
                [string]$existingReconciliation['pluginId'] -ieq [string]$newReconciliation['pluginId'] -and
                [string]$existingReconciliation['requiredContractVersion'] -eq [string]$newReconciliation['requiredContractVersion'] -and
                $existingReconciliation.Contains('settings')) {
                $newReconciliation['settings'] = $existingReconciliation['settings']
                $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $resolvedOperationId -Component 'Core' -EventName 'ExistingReconciliationSettingsPreserved' -Message 'Re-onboarding preserved the existing user-configured reconciliation settings because the reconciliation plugin and contract remain unchanged.' -Context @{ApplicationId=[string]$normalization.ApplicationDefinition.id;PluginId=[string]$newReconciliation['pluginId']}))
            }
        }
        catch {
            # Do not silently discard settings if the existing manifest cannot be
            # read: make the condition visible and let normal persistence validation
            # decide whether onboarding can safely replace the definition.
            $warnings.Add([pscustomobject][ordered]@{
                Code='ExistingReconciliationSettingsReadFailed'
                Message='Wintainium could not read the existing manifest to preserve its reconciliation settings during re-onboarding.'
                Detail=$_.Exception.GetType().Name
            })
        }
    }

    & $addStage 4 'DefinitionNormalization' 'Completed' $true $null 'The source was normalized into an application definition.'

    try {
        $manifestPath=Set-WintainiumApplicationDefinition -ApplicationDefinition $normalization.ApplicationDefinition -ManifestRoot $ManifestRoot -SchemaPath $SchemaPath
    }
    catch {
        $errors.Add([pscustomobject][ordered]@{Code='ApplicationDefinitionPersistenceFailed';Path='$.ManifestRoot';Message=$_.Exception.Message})
        & $addStage 5 'Persistence' 'Failed' $false 'ApplicationDefinitionPersistenceFailed' $_.Exception.Message
        return [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$false;Status='ApplicationDefinitionPersistenceFailed';SourceResolution=$sourceResolution;ApplicationDefinition=$normalization.ApplicationDefinition;ManifestPath=$null;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray();Stages=$stages.ToArray()}
    }

    $logEvents.Add((New-WintainiumLogEvent -Severity Information -OperationId $resolvedOperationId -Component 'Core' -EventName 'ApplicationOnboardingCompleted' -Message 'Application source was resolved, normalized, and persisted.' -Context @{ApplicationId=[string]$normalization.ApplicationDefinition.Id;ManifestPath=$manifestPath}))
    & $addStage 5 'Persistence' 'Completed' $true $null 'The application definition was persisted to the manifest collection.'
    [pscustomobject][ordered]@{OperationId=$resolvedOperationId;IsSuccessful=$true;Status='Resolved';SourceResolution=$sourceResolution;ApplicationDefinition=$normalization.ApplicationDefinition;ManifestPath=$manifestPath;Errors=$errors.ToArray();Warnings=$warnings.ToArray();LogEvents=$logEvents.ToArray();Stages=$stages.ToArray()}
}
