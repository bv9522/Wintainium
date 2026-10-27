function Invoke-WintainiumApplicationLifecycle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$ManifestPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$StateRoot,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$MachineArchitecture,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$DownloadRoot,
        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),
        [ValidateRange(1, 2147483647)] [int]$InstallerTimeoutMilliseconds = 600000,
        [ValidateSet('Update','Install')] [string]$OperationKind = 'Update',
        [bool]$AllowLegacyMd5Verification = $false,
        [System.Net.Http.HttpClient]$HttpClient,
        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
    )

    if ([string]::IsNullOrWhiteSpace($StateRoot)) {
        return [pscustomobject][ordered]@{ IsSuccessful=$false; WasCancelled=$false; OperationId=$null; Request=$null; State=$null; StageResults=@(); Error=[pscustomobject][ordered]@{ Code='ApplicationUpdateStateRootInvalid'; Message='StateRoot must not be empty or whitespace.' } }
    }

    $requestResult = New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
    if ($null -eq $requestResult -or -not $requestResult.IsValid -or $null -eq $requestResult.Request) {
        return [pscustomobject][ordered]@{ IsSuccessful=$false; WasCancelled=$false; OperationId=$null; Request=$null; State=$null; StageResults=@(); Error=[pscustomobject][ordered]@{ Code='ApplicationUpdateOrchestrationRequestInvalid'; Message=if ($null -ne $requestResult.Errors -and @($requestResult.Errors).Count -gt 0) { [string]@($requestResult.Errors)[0].Message } else { 'The application update orchestration request could not be created.' } } }
    }

    $request = $requestResult.Request
    $environment = Get-WintainiumEnvironment -Overrides ([pscustomobject]@{ MachineArchitecture=$MachineArchitecture })
    $planResult = New-WintainiumOrchestrationStagePlan -OrchestrationRequest $request
    if ($null -eq $planResult -or -not $planResult.IsValid -or $null -eq $planResult.Plan) {
        return [pscustomobject][ordered]@{ IsSuccessful=$false; WasCancelled=$false; OperationId=$request.OperationId; Request=$request; State=$null; StageResults=@(); Error=[pscustomobject][ordered]@{ Code='ApplicationUpdateStagePlanInvalid'; Message=if ($null -ne $planResult.Errors -and @($planResult.Errors).Count -gt 0) { [string]@($planResult.Errors)[0].Message } else { 'The application update stage plan could not be created.' } } }
    }

    $plan = $planResult.Plan
    $cancellationContext = [pscustomobject][ordered]@{ OperationId=$request.OperationId; CancellationToken=$CancellationToken }

    $isLifecycleExecutionRequired = {
        param([psobject]$Decision)
        if ($null -eq $Decision) { return $false }
        if ($OperationKind -eq 'Install') {
            return [string]$Decision.Status -eq 'InstallAvailable' -and [bool]$Decision.IsInstallAvailable
        }
        return [string]$Decision.Status -eq 'UpdateAvailable' -and [bool]$Decision.IsUpdateAvailable
    }

    $stageFactory = {
        param($stage, $state, $context)
        $getResult = { param([string]$name); $entry=@($state.StageResults | Where-Object { [string]$_.Name -eq $name }) | Select-Object -Last 1; if($null -eq $entry){return $null}; return $entry.Result }
        $result=[pscustomobject][ordered]@{}; $executor=$null
        switch([string]$stage.Name){
            'ManifestValidation' { $result=[pscustomobject][ordered]@{ManifestPath=$request.ManifestPath;PluginRoot=$PluginRoot;SchemaPath=$SchemaPath;OperationId=[string]$request.OperationId};$executor={param($StageInput,$CancellationToken);$normalize={param($value,[bool]$successful);if($null -eq $value){return [pscustomobject][ordered]@{IsSuccessful=$successful}};$copy=[ordered]@{};foreach($property in $value.PSObject.Properties){$copy[$property.Name]=$property.Value};$copy['IsSuccessful']=$successful;[pscustomobject]$copy};$validation=Test-WintainiumApplicationDefinition -ManifestPath $StageInput.ManifestPath -PluginRoot $StageInput.PluginRoot -SchemaPath $StageInput.SchemaPath -OperationId $StageInput.OperationId;& $normalize $validation ([bool]$validation.IsValid)} }
            'ReleaseDiscovery' { $validation=& $getResult 'ManifestValidation';$result=[pscustomobject][ordered]@{Validation=$validation;OperationId=[string]$request.OperationId};$executor={param($StageInput,$CancellationToken);$normalize={param($value,[bool]$successful);if($null -eq $value){return [pscustomobject][ordered]@{IsSuccessful=$successful}};$copy=[ordered]@{};foreach($property in $value.PSObject.Properties){$copy[$property.Name]=$property.Value};$copy['IsSuccessful']=$successful;[pscustomobject]$copy};$validation=$StageInput.Validation;if($null -eq $validation -or -not [bool]$validation.IsSuccessful){return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$false;Status='Blocked';FailureKind='ManifestValidationRequired';Errors=@($validation.Errors)}};$manifest=$validation.Manifest;$provider=$validation.ProviderPlugin;$providerSettings=@{};if($manifest.Source.settings -is [System.Collections.IDictionary]){foreach($settingName in $manifest.Source.settings.Keys){$providerSettings[[string]$settingName]=$manifest.Source.settings[$settingName]}};if($OperationKind -eq 'Install' -and [string]$provider.PluginId -eq 'Wintainium.provider.github-releases' -and -not $providerSettings.ContainsKey('maxPages')){$providerSettings['maxPages']=1};$providerRequest=[pscustomobject][ordered]@{OperationId=$StageInput.OperationId;ApplicationId=[string]$manifest.Id;ProviderId=[string]$provider.PluginId;RequiredContractVersion=[string]$manifest.Source.requiredContractVersion;Settings=$providerSettings;DiscoveryContext=[pscustomobject][ordered]@{ReleaseChannel=[string]$manifest.Release.channel;ArtifactFormats=@($manifest.Artifact.formats);Architectures=@($manifest.Artifact.architectures);AllowUnknownArchitecture=[bool]$manifest.Artifact.allowUnknownArchitecture}};$providerResult=Invoke-WintainiumProviderOperation -Provider $provider -Request $providerRequest;& $normalize $providerResult ([bool]$providerResult.IsSuccessful)} }
            'UpdateDecision' { $validation=& $getResult 'ManifestValidation';$release=& $getResult 'ReleaseDiscovery';$result=[pscustomobject][ordered]@{Validation=$validation;Release=$release;StateRoot=$StateRoot;MachineArchitecture=$MachineArchitecture;Environment=$environment;OperationId=[string]$request.OperationId};$executor={param($StageInput,$CancellationToken);$normalize={param($value,[bool]$successful);if($null -eq $value){return [pscustomobject][ordered]@{IsSuccessful=$successful}};$copy=[ordered]@{};foreach($property in $value.PSObject.Properties){$copy[$property.Name]=$property.Value};$copy['IsSuccessful']=$successful;[pscustomobject]$copy};$validation=$StageInput.Validation;$release=$StageInput.Release;if($null -eq $release -or -not [bool]$release.IsSuccessful){return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$false;Status='ProviderDiscoveryUnsuccessful';Errors=if($null -ne $release){@($release.Errors)}else{@()};Warnings=if($null -ne $release){@($release.Warnings)}else{@()};LogEvents=if($null -ne $release){@($release.LogEvents)}else{@()}}};$manifest=$validation.Manifest;$installedState=Get-WintainiumInstalledApplicationState -StateRoot $StageInput.StateRoot -ApplicationId ([string]$manifest.Id);$providerResult=[pscustomobject][ordered]@{IsSuccessful=$true;Status=$release.Status;Releases=@($release.Releases);Errors=@($release.Errors);Warnings=@($release.Warnings);LogEvents=@($release.LogEvents)};if ($OperationKind -eq 'Install') {
                $decision=Get-WintainiumApplicationInstallDecision -Manifest $manifest -InstalledState $installedState -ProviderResult $providerResult -MachineArchitecture $StageInput.MachineArchitecture -Environment $StageInput.Environment
            }
            else {
                $decisionInput=New-WintainiumUpdateDecisionInput -Manifest $manifest -InstalledState $installedState -ProviderResult $providerResult
                $decision=Get-WintainiumUpdateDecision -UpdateDecisionInput $decisionInput -MachineArchitecture $StageInput.MachineArchitecture -Environment $StageInput.Environment
            }
            & $normalize $decision $true} }
            'Download' { $decision=& $getResult 'UpdateDecision';$result=[pscustomobject][ordered]@{Decision=$decision;DownloadRoot=$DownloadRoot;HttpClient=$HttpClient;OperationId=[string]$request.OperationId};$executor={param($StageInput,$CancellationToken);$normalize={param($value,[bool]$successful);if($null -eq $value){return [pscustomobject][ordered]@{IsSuccessful=$successful}};$copy=[ordered]@{};foreach($property in $value.PSObject.Properties){$copy[$property.Name]=$property.Value};$copy['IsSuccessful']=$successful;[pscustomobject]$copy};$decision=$StageInput.Decision;if($null -eq $decision -or -not (& $isLifecycleExecutionRequired $decision)){return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$true;Status='Skipped';ReasonCode=if ($OperationKind -eq 'Install') { 'NoInstallRequired' } else { 'NoUpdateAvailable' }}};$downloadRequest=New-WintainiumDownloadRequest -UpdateDecision $decision -OperationId $StageInput.OperationId;$parameters=@{DownloadRequest=$downloadRequest;DownloadRoot=$StageInput.DownloadRoot;CancellationToken=$CancellationToken};if($null -ne $StageInput.HttpClient){$parameters.HttpClient=$StageInput.HttpClient};$downloadResult=Invoke-WintainiumDownload @parameters;$downloadSuccessful=$false;if($null -ne $downloadResult){$successProperty=$downloadResult.PSObject.Properties['IsSuccessful'];$statusProperty=$downloadResult.PSObject.Properties['Status'];if($null -ne $successProperty){$downloadSuccessful=[bool]$successProperty.Value}elseif($null -ne $statusProperty){$downloadSuccessful=[string]$statusProperty.Value -eq 'Downloaded'}};& $normalize $downloadResult $downloadSuccessful} }
            'Verification' {
                $decision=& $getResult 'UpdateDecision'
                $download=& $getResult 'Download'
                $validation=& $getResult 'ManifestValidation'
                $result=[pscustomobject][ordered]@{
                    Decision=$decision
                    Download=$download
                    DownloadRoot=$DownloadRoot
                    HttpClient=$HttpClient
                    Manifest=$validation.Manifest
                    MachineArchitecture=$MachineArchitecture
                    OperationId=[string]$request.OperationId
                }
                $executor={
                    param($StageInput,$CancellationToken)
                    $normalize={
                        param($value,[bool]$successful)
                        if($null -eq $value){return [pscustomobject][ordered]@{IsSuccessful=$successful}}
                        $copy=[ordered]@{}
                        foreach($property in $value.PSObject.Properties){$copy[$property.Name]=$property.Value}
                        $copy['IsSuccessful']=$successful
                        [pscustomobject]$copy
                    }
                    $decision=$StageInput.Decision
                    if($null -eq $decision -or -not (& $isLifecycleExecutionRequired $decision)){
                        return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$true;Status='Skipped';ReasonCode=if ($OperationKind -eq 'Install') { 'NoInstallRequired' } else { 'NoUpdateAvailable' }}
                    }

                    $verificationParameters=@{DownloadResult=$StageInput.Download;SelectedArtifact=$decision.SelectedArtifact;OperationId=$StageInput.OperationId}
                    if($AllowLegacyMd5Verification){$verificationParameters.AllowLegacyMd5Verification=$true}
                    $verification=Invoke-WintainiumArtifactVerification @verificationParameters
                    $verificationSuccessful=if($null -ne $verification -and $verification.PSObject.Properties['IsSuccessful']){[bool]$verification.IsSuccessful}else{[string]$verification.Status -eq 'Verified'}

                    if($verificationSuccessful -and $decision.SelectedArtifact.PSObject.Properties['ArchitectureInspectionRequired'] -and [bool]$decision.SelectedArtifact.ArchitectureInspectionRequired){
                        $inspection=Resolve-WintainiumInstallerPayloadArchitecture -DownloadResult $StageInput.Download -SelectedArtifact $decision.SelectedArtifact -VerificationResult $verification -MachineArchitecture $StageInput.MachineArchitecture
                        if($inspection.IsSuccessful){
                            $decision.SelectedArtifact.Architecture=[string]$inspection.ResolvedArchitecture
                            $eligibility=Test-WintainiumArtifactEligibility -Artifact $decision.SelectedArtifact -Manifest $StageInput.Manifest -MachineArchitecture $StageInput.MachineArchitecture
                            if(-not $eligibility.Eligible){
                                $inspection=[pscustomobject][ordered]@{IsSuccessful=$false;Status='Unresolved';ReasonCode=$eligibility.ReasonCode;Reason=$eligibility.Reason;PayloadArchitectures=@($inspection.PayloadArchitectures);ResolvedArchitecture=$null;Inspector=$inspection.Inspector}
                            }
                        }

                        if($inspection.IsSuccessful){
                            $decision.SelectedArtifact.PSObject.Properties.Remove('ArchitectureInspectionRequired')
                            $verification | Add-Member -NotePropertyName ArchitectureInspection -NotePropertyValue $inspection -Force
                            return & $normalize $verification $true
                        }

                        # If static inspection cannot establish compatibility, try a known-architecture
                        # artifact from the same release. The unknown EXE is never sent to the installer.
                        $fallbackArtifacts=@($decision.SelectedRelease.Artifacts | Where-Object {
                            [string]$_.Uri -ne [string]$decision.SelectedArtifact.Uri -and
                            -not ([string]$_.Format -eq 'exe' -and [string]$_.Architecture -eq 'unknown')
                        })
                        $fallbackSelection=$null
                        if($fallbackArtifacts.Count -gt 0){
                            $releaseProperties=[ordered]@{}
                            foreach($property in $decision.SelectedRelease.PSObject.Properties){$releaseProperties[$property.Name]=$property.Value}
                            $releaseProperties['Artifacts']=$fallbackArtifacts
                            $fallbackRelease=[pscustomobject]$releaseProperties
                            $fallbackSelection=Select-WintainiumArtifact -Release $fallbackRelease -Manifest $StageInput.Manifest -MachineArchitecture $StageInput.MachineArchitecture
                        }

                        if($null -ne $fallbackSelection -and $null -ne $fallbackSelection.SelectedArtifact){
                            $decisionProperties=[ordered]@{}
                            foreach($property in $decision.PSObject.Properties){$decisionProperties[$property.Name]=$property.Value}
                            $decisionProperties['SelectedRelease']=$fallbackRelease
                            $decisionProperties['SelectedArtifact']=$fallbackSelection.SelectedArtifact
                            $fallbackDecision=[pscustomobject]$decisionProperties
                            $fallbackRequest=New-WintainiumDownloadRequest -UpdateDecision $fallbackDecision -OperationId $StageInput.OperationId
                            $fallbackDownloadParameters=@{DownloadRequest=$fallbackRequest;DownloadRoot=$StageInput.DownloadRoot;CancellationToken=$CancellationToken}
                            if($null -ne $StageInput.HttpClient){$fallbackDownloadParameters.HttpClient=$StageInput.HttpClient}
                            $fallbackDownload=Invoke-WintainiumDownload @fallbackDownloadParameters
                            $StageInput.Download | Add-Member -NotePropertyName FallbackDownloadResult -NotePropertyValue $fallbackDownload -Force

                            if($null -ne $fallbackDownload -and [string]$fallbackDownload.Status -eq 'Downloaded'){
                                $fallbackVerificationParameters=@{DownloadResult=$fallbackDownload;SelectedArtifact=$fallbackSelection.SelectedArtifact;OperationId=$StageInput.OperationId}
                                if($AllowLegacyMd5Verification){$fallbackVerificationParameters.AllowLegacyMd5Verification=$true}
                                $fallbackVerification=Invoke-WintainiumArtifactVerification @fallbackVerificationParameters
                                $fallbackVerificationSuccessful=if($null -ne $fallbackVerification -and $fallbackVerification.PSObject.Properties['IsSuccessful']){[bool]$fallbackVerification.IsSuccessful}else{[string]$fallbackVerification.Status -eq 'Verified'}
                                $fallbackVerification | Add-Member -NotePropertyName ArchitectureInspection -NotePropertyValue $inspection -Force
                                $fallbackVerification | Add-Member -NotePropertyName ArchitectureInspectionFallbackUsed -NotePropertyValue $true -Force
                                $fallbackVerification | Add-Member -NotePropertyName FallbackDownloadResult -NotePropertyValue $fallbackDownload -Force
                                if($fallbackVerificationSuccessful){
                                    $decision.SelectedRelease=$fallbackRelease
                                    $decision.SelectedArtifact=$fallbackSelection.SelectedArtifact
                                    return & $normalize $fallbackVerification $true
                                }
                                return & $normalize $fallbackVerification $false
                            }
                        }

                        $verification.Status='Failed'
                        $verification.IsSuccessful=$false
                        $verification.FailureKind='ArchitectureInspectionUnresolved'
                        $verification.ErrorMessage=[string]$inspection.Reason
                        $verification | Add-Member -NotePropertyName ArchitectureInspection -NotePropertyValue $inspection -Force
                        $verificationSuccessful=$false
                    }

                    & $normalize $verification $verificationSuccessful
                }
            }
            'InstallerSelection' { $validation=& $getResult 'ManifestValidation';$decision=& $getResult 'UpdateDecision';$result=[pscustomobject][ordered]@{Validation=$validation;Decision=$decision;OperationId=[string]$request.OperationId};$executor={param($StageInput,$CancellationToken);$normalize={param($value,[bool]$successful);if($null -eq $value){return [pscustomobject][ordered]@{IsSuccessful=$successful}};$copy=[ordered]@{};foreach($property in $value.PSObject.Properties){$copy[$property.Name]=$property.Value};$copy['IsSuccessful']=$successful;[pscustomobject]$copy};$decision=$StageInput.Decision;if($null -eq $decision -or -not (& $isLifecycleExecutionRequired $decision)){return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$true;Status='Skipped';ReasonCode=if ($OperationKind -eq 'Install') { 'NoInstallRequired' } else { 'NoUpdateAvailable' }}};$installerPlugins = if ($StageInput.Validation.PSObject.Properties['InstallerPlugins']) { @($StageInput.Validation.InstallerPlugins) } else { @($StageInput.Validation.InstallerPlugin) };$selection=Select-WintainiumInstaller -Manifest $StageInput.Validation.Manifest -Artifact $decision.SelectedArtifact -Plugins $installerPlugins;& $normalize $selection ([bool]$selection.IsSelected)} }
            'Installation' { $validation=& $getResult 'ManifestValidation';$decision=& $getResult 'UpdateDecision';$download=& $getResult 'Download';$verification=& $getResult 'Verification';$selection=& $getResult 'InstallerSelection';$result=[pscustomobject][ordered]@{Validation=$validation;Decision=$decision;Download=$download;Verification=$verification;Selection=$selection;InstallerTimeoutMilliseconds=$InstallerTimeoutMilliseconds;OperationId=[string]$request.OperationId};$executor={param($StageInput,$CancellationToken);$normalize={param($value,[bool]$successful);if($null -eq $value){return [pscustomobject][ordered]@{IsSuccessful=$successful}};$copy=[ordered]@{};foreach($property in $value.PSObject.Properties){$copy[$property.Name]=$property.Value};$copy['IsSuccessful']=$successful;[pscustomobject]$copy};$decision=$StageInput.Decision;if($null -eq $decision -or -not (& $isLifecycleExecutionRequired $decision)){return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$true;Status='Skipped';ReasonCode=if ($OperationKind -eq 'Install') { 'NoInstallRequired' } else { 'NoUpdateAvailable' }}};if($null -eq $StageInput.Verification -or [string]$StageInput.Verification.Status -notin @('Verified','VerifiedWithReducedAssurance')){return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$false;Status='Blocked';FailureKind='VerificationRequired';ErrorMessage='Installation requires successful artifact verification.'}};if($null -eq $StageInput.Selection -or -not [bool]$StageInput.Selection.IsSelected){return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$false;Status='Blocked';FailureKind='InstallerSelectionRequired';ErrorMessage='Installation requires successful installer selection.'}};$installerDownload=if($StageInput.Verification.PSObject.Properties['FallbackDownloadResult']){$StageInput.Verification.FallbackDownloadResult}else{$StageInput.Download};$installerRequestResult=New-WintainiumInstallerRequest -DownloadResult $installerDownload -Manifest $StageInput.Validation.Manifest -OperationId $StageInput.OperationId;if(-not $installerRequestResult.IsValid){return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$false;Status='Failed';FailureKind='InstallerRequestInvalid';Errors=@($installerRequestResult.Errors)}};$invocationResult=New-WintainiumInstallerInvocation -Selection $StageInput.Selection -Request $installerRequestResult.Request;if(-not $invocationResult.IsValid){return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$false;Status='Failed';FailureKind='InstallerInvocationInvalid';Error=$invocationResult.Error}};$installation=Invoke-WintainiumInstallerOperation -Invocation $invocationResult.Invocation -TimeoutMilliseconds $StageInput.InstallerTimeoutMilliseconds -CancellationToken $CancellationToken;$installationSuccessful=if($null -ne $installation -and $installation.PSObject.Properties['IsSuccessful']){[bool]$installation.IsSuccessful}else{[string]$installation.Status -eq 'Completed'};& $normalize $installation $installationSuccessful} }
            'Reconciliation' { $validation=& $getResult 'ManifestValidation';$decision=& $getResult 'UpdateDecision';$installation=& $getResult 'Installation';$result=[pscustomobject][ordered]@{Validation=$validation;Decision=$decision;Installation=$installation;StateRoot=$StateRoot;OperationId=[string]$request.OperationId};$executor={param($StageInput,$CancellationToken);$normalize={param($value,[bool]$successful);if($null -eq $value){return [pscustomobject][ordered]@{IsSuccessful=$successful}};$copy=[ordered]@{};foreach($property in $value.PSObject.Properties){$copy[$property.Name]=$property.Value};$copy['IsSuccessful']=$successful;[pscustomobject]$copy};$decision=$StageInput.Decision;if($null -eq $decision -or -not (& $isLifecycleExecutionRequired $decision)){return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$true;Status='Skipped';ReasonCode=if ($OperationKind -eq 'Install') { 'NoInstallRequired' } else { 'NoUpdateAvailable' }}};if($null -eq $StageInput.Installation -or [string]$StageInput.Installation.Status -ne 'Completed'){return [pscustomobject][ordered]@{OperationId=$StageInput.OperationId;IsSuccessful=$false;Status='Blocked';FailureKind='InstallationRequired';ErrorMessage='Reconciliation requires a completed installation.'}};$applicationId=[string]$StageInput.Validation.Manifest.Id;$priorState=Get-WintainiumInstalledApplicationState -StateRoot $StageInput.StateRoot -ApplicationId $applicationId;$reconciliationRequest=[pscustomobject][ordered]@{OperationId=$StageInput.OperationId;ApplicationId=$applicationId;Manifest=$StageInput.Validation.Manifest;PriorState=$priorState};$reconciliation=Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $StageInput.Validation.ReconciliationPlugin -Request $reconciliationRequest;$reconciliationSuccessful=[bool]$reconciliation.IsSuccessful;$reconciliation=& $normalize $reconciliation $reconciliationSuccessful;if(-not $reconciliationSuccessful){return $reconciliation};$authoritative=Invoke-WintainiumAuthoritativeStateReconciliation -StateRoot $StageInput.StateRoot -OperationId $StageInput.OperationId -ApplicationId $applicationId -ReconciliationResult $reconciliation -PriorState $priorState;$reconciliation | Add-Member -NotePropertyName AuthoritativeStateResult -NotePropertyValue $authoritative -Force;if(-not [bool]$authoritative.IsSuccessful){$reconciliation.IsSuccessful=$false;$reconciliation.Status='Failed';$reconciliation | Add-Member -NotePropertyName FailureKind -NotePropertyValue 'AuthoritativeStateReconciliationFailed' -Force;$reconciliation | Add-Member -NotePropertyName Error -NotePropertyValue ([pscustomobject][ordered]@{Code='AuthoritativeStateReconciliationFailed';Message='Authoritative installed state reconciliation failed.';Detail=$authoritative}) -Force};$reconciliation} }
            default { throw "Unsupported application lifecycle stage '$($stage.Name)'." }
        }
        [pscustomobject][ordered]@{StageInput=$result;StageExecutor=$executor}
    }

    $lifecycleResult = Invoke-WintainiumOrchestrationLifecycle -Request $request -StagePlan $plan -CancellationContext $cancellationContext -StageFactory $stageFactory

    $downloadStage = @($lifecycleResult.StageResults | Where-Object { [string]$_.StageName -eq 'Download' }) | Select-Object -Last 1
    $downloadResult = $null
    if ($null -ne $downloadStage -and $null -ne $downloadStage.PSObject.Properties['Execution']) {
        $execution = $downloadStage.Execution
        if ($null -ne $execution -and $null -ne $execution.PSObject.Properties['Result']) {
            $downloadResult = $execution.Result
        }
        elseif ($null -ne $execution) {
            $downloadResult = $execution
        }
    }
    $artifactOutcome = if ([bool]$lifecycleResult.WasCancelled) {
        'Cancelled'
    } elseif ([bool]$lifecycleResult.IsSuccessful) {
        'Completed'
    } else {
        'Failed'
    }

    $artifactLifecycle = Invoke-WintainiumDownloadArtifactCleanup -DownloadResult $downloadResult -DownloadRoot $DownloadRoot -Outcome $artifactOutcome
    $lifecycleResult | Add-Member -NotePropertyName ArtifactLifecycle -NotePropertyValue $artifactLifecycle -Force
    if ($null -ne $downloadResult -and $downloadResult.PSObject.Properties['FallbackDownloadResult']) {
        $fallbackArtifactLifecycle = Invoke-WintainiumDownloadArtifactCleanup -DownloadResult $downloadResult.FallbackDownloadResult -DownloadRoot $DownloadRoot -Outcome $artifactOutcome
        $lifecycleResult | Add-Member -NotePropertyName FallbackArtifactLifecycle -NotePropertyValue $fallbackArtifactLifecycle -Force
    }

    # Artifact cleanup is deliberately non-authoritative. A successful update remains
    # successful even if the final file removal cannot be completed; the cleanup result
    # preserves the diagnostic while leaving the installed state authoritative.
    $lifecycleResult
}
