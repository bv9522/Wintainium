function Invoke-WintainiumApplicationUpdateLifecycle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$ManifestPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$StateRoot,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$MachineArchitecture,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$DownloadRoot,
        [string]$PluginRoot = $script:WintainiumDefaultPluginRoot,
        [string]$SchemaPath = (Join-Path -Path $script:WintainiumSchemaRoot -ChildPath 'application-manifest.schema.json'),
        [ValidateRange(1, 2147483647)] [int]$InstallerTimeoutMilliseconds = 600000,
        [System.Net.Http.HttpClient]$HttpClient,
        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
    )

    if ([string]::IsNullOrWhiteSpace($StateRoot)) { throw [System.ArgumentException]::new('StateRoot must not be empty or whitespace.') }

    $requestResult = New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
    if ($null -eq $requestResult -or -not $requestResult.IsValid -or $null -eq $requestResult.Request) {
        return [pscustomobject][ordered]@{ IsSuccessful=$false; WasCancelled=$false; OperationId=$null; Request=$null; State=$null; StageResults=@(); Error=[pscustomobject][ordered]@{ Code='ApplicationUpdateOrchestrationRequestInvalid'; Message=if ($null -ne $requestResult.Errors -and @($requestResult.Errors).Count -gt 0) { [string]@($requestResult.Errors)[0].Message } else { 'The application update orchestration request could not be created.' } } }
    }

    $request = $requestResult.Request
    $planResult = New-WintainiumOrchestrationStagePlan -OrchestrationRequest $request
    if ($null -eq $planResult -or -not $planResult.IsValid -or $null -eq $planResult.Plan) {
        return [pscustomobject][ordered]@{ IsSuccessful=$false; WasCancelled=$false; OperationId=$request.OperationId; Request=$request; State=$null; StageResults=@(); Error=[pscustomobject][ordered]@{ Code='ApplicationUpdateStagePlanInvalid'; Message=if ($null -ne $planResult.Errors -and @($planResult.Errors).Count -gt 0) { [string]@($planResult.Errors)[0].Message } else { 'The application update stage plan could not be created.' } } }
    }

    $plan = $planResult.Plan
    $cancellationContext = [pscustomobject][ordered]@{ OperationId=$request.OperationId; CancellationToken=$CancellationToken }

    $stageFactory = {
        param($stage, $state, $context)

        $getResult = {
            param([string]$name)
            $entry = @($state.StageResults | Where-Object { [string]$_.Name -eq $name }) | Select-Object -Last 1
            if ($null -eq $entry) { return $null }
            return $entry.Result
        }

        $result = [pscustomobject][ordered]@{}
        $executor = $null

        switch ([string]$stage.Name) {
            'ManifestValidation' {
                $result = [pscustomobject][ordered]@{
                    ManifestPath=$request.ManifestPath
                    PluginRoot=$PluginRoot
                    SchemaPath=$SchemaPath
                    OperationId=[string]$request.OperationId
                }
                $executor = {
                    param($StageInput, $CancellationToken)
                    $normalize = {
                        param($value, [bool]$successful)
                        if ($null -eq $value) { return [pscustomobject][ordered]@{ IsSuccessful=$successful } }
                        $copy = [ordered]@{}
                        foreach ($property in $value.PSObject.Properties) { $copy[$property.Name] = $property.Value }
                        $copy['IsSuccessful'] = $successful
                        [pscustomobject]$copy
                    }
                    $validation = Test-WintainiumApplicationDefinition -ManifestPath $StageInput.ManifestPath -PluginRoot $StageInput.PluginRoot -SchemaPath $StageInput.SchemaPath -OperationId $StageInput.OperationId
                    & $normalize $validation ([bool]$validation.IsValid)
                }
            }
            'ReleaseDiscovery' {
                $validation = & $getResult 'ManifestValidation'
                $result = [pscustomobject][ordered]@{
                    Validation=$validation
                    OperationId=[string]$request.OperationId
                }
                $executor = {
                    param($StageInput, $CancellationToken)
                    $normalize = {
                        param($value, [bool]$successful)
                        if ($null -eq $value) { return [pscustomobject][ordered]@{ IsSuccessful=$successful } }
                        $copy = [ordered]@{}
                        foreach ($property in $value.PSObject.Properties) { $copy[$property.Name] = $property.Value }
                        $copy['IsSuccessful'] = $successful
                        [pscustomobject]$copy
                    }
                    $validation = $StageInput.Validation
                    if ($null -eq $validation -or -not [bool]$validation.IsSuccessful) { return [pscustomobject][ordered]@{ OperationId=$StageInput.OperationId; IsSuccessful=$false; Status='Blocked'; FailureKind='ManifestValidationRequired'; Errors=@($validation.Errors) } }
                    $manifest = $validation.Manifest
                    $provider = $validation.ProviderPlugin
                    $providerRequest = [pscustomobject][ordered]@{
                        OperationId=$StageInput.OperationId; ApplicationId=[string]$manifest.Id; ProviderId=[string]$provider.PluginId
                        RequiredContractVersion=[string]$manifest.Source.requiredContractVersion
                        Settings=if ($manifest.Source.settings -is [System.Collections.IDictionary]) { $manifest.Source.settings } else { @{} }
                        DiscoveryContext=[pscustomobject][ordered]@{ ReleaseChannel=[string]$manifest.Release.channel; ArtifactFormats=@($manifest.Artifact.formats); Architectures=@($manifest.Artifact.architectures); AllowUnknownArchitecture=[bool]$manifest.Artifact.allowUnknownArchitecture }
                    }
                    $providerResult = Invoke-WintainiumProviderOperation -Provider $provider -Request $providerRequest
                    & $normalize $providerResult ([bool]$providerResult.IsSuccessful)
                }
            }
            'UpdateDecision' {
                $validation = & $getResult 'ManifestValidation'
                $release = & $getResult 'ReleaseDiscovery'
                $result = [pscustomobject][ordered]@{
                    Validation=$validation
                    Release=$release
                    StateRoot=$StateRoot
                    MachineArchitecture=$MachineArchitecture
                    OperationId=[string]$request.OperationId
                }
                $executor = {
                    param($StageInput, $CancellationToken)
                    $normalize = {
                        param($value, [bool]$successful)
                        if ($null -eq $value) { return [pscustomobject][ordered]@{ IsSuccessful=$successful } }
                        $copy = [ordered]@{}
                        foreach ($property in $value.PSObject.Properties) { $copy[$property.Name] = $property.Value }
                        $copy['IsSuccessful'] = $successful
                        [pscustomobject]$copy
                    }
                    $validation = $StageInput.Validation
                    $release = $StageInput.Release
                    if ($null -eq $release -or -not [bool]$release.IsSuccessful) { return [pscustomobject][ordered]@{ OperationId=$StageInput.OperationId; IsSuccessful=$false; Status='ProviderDiscoveryUnsuccessful'; Errors=if ($null -ne $release) { @($release.Errors) } else { @() }; Warnings=if ($null -ne $release) { @($release.Warnings) } else { @() }; LogEvents=if ($null -ne $release) { @($release.LogEvents) } else { @() } } }
                    $manifest = $validation.Manifest
                    $installedState = Get-WintainiumInstalledApplicationState -StateRoot $StageInput.StateRoot -ApplicationId ([string]$manifest.Id)
                    $providerResult = [pscustomobject][ordered]@{ IsSuccessful=$true; Status=$release.Status; Releases=@($release.Releases); Errors=@($release.Errors); Warnings=@($release.Warnings); LogEvents=@($release.LogEvents) }
                    $decisionInput = New-WintainiumUpdateDecisionInput -Manifest $manifest -InstalledState $installedState -ProviderResult $providerResult
                    $decision = Get-WintainiumUpdateDecision -UpdateDecisionInput $decisionInput -MachineArchitecture $StageInput.MachineArchitecture
                    & $normalize $decision $true
                }
            }
            'Download' {
                $decision = & $getResult 'UpdateDecision'
                $result = [pscustomobject][ordered]@{
                    Decision=$decision
                    DownloadRoot=$DownloadRoot
                    HttpClient=$HttpClient
                    OperationId=[string]$request.OperationId
                }
                $executor = {
                    param($StageInput, $CancellationToken)
                    $normalize = {
                        param($value, [bool]$successful)
                        if ($null -eq $value) { return [pscustomobject][ordered]@{ IsSuccessful=$successful } }
                        $copy = [ordered]@{}
                        foreach ($property in $value.PSObject.Properties) { $copy[$property.Name] = $property.Value }
                        $copy['IsSuccessful'] = $successful
                        [pscustomobject]$copy
                    }
                    $decision = $StageInput.Decision
                    if ($null -eq $decision -or [string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) { return [pscustomobject][ordered]@{ OperationId=$StageInput.OperationId; IsSuccessful=$true; Status='Skipped'; ReasonCode='NoUpdateAvailable' } }
                    $downloadRequest = New-WintainiumDownloadRequest -UpdateDecision $decision -OperationId $StageInput.OperationId
                    $parameters = @{ DownloadRequest=$downloadRequest; DownloadRoot=$StageInput.DownloadRoot; CancellationToken=$CancellationToken }
                    if ($null -ne $StageInput.HttpClient) { $parameters.HttpClient=$StageInput.HttpClient }
                    $downloadResult = Invoke-WintainiumDownload @parameters
                    $downloadSuccessful = if ($null -ne $downloadResult -and $downloadResult.PSObject.Properties['IsSuccessful']) { [bool]$downloadResult.IsSuccessful } else { [string]$downloadResult.Status -eq 'Downloaded' }
                    & $normalize $downloadResult $downloadSuccessful
                }
            }
            'Verification' {
                $decision = & $getResult 'UpdateDecision'
                $download = & $getResult 'Download'
                $result = [pscustomobject][ordered]@{
                    Decision=$decision
                    Download=$download
                    OperationId=[string]$request.OperationId
                }
                $executor = {
                    param($StageInput, $CancellationToken)
                    $normalize = {
                        param($value, [bool]$successful)
                        if ($null -eq $value) { return [pscustomobject][ordered]@{ IsSuccessful=$successful } }
                        $copy = [ordered]@{}
                        foreach ($property in $value.PSObject.Properties) { $copy[$property.Name] = $property.Value }
                        $copy['IsSuccessful'] = $successful
                        [pscustomobject]$copy
                    }
                    $decision = $StageInput.Decision
                    if ($null -eq $decision -or [string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) { return [pscustomobject][ordered]@{ OperationId=$StageInput.OperationId; IsSuccessful=$true; Status='Skipped'; ReasonCode='NoUpdateAvailable' } }
                    $verification = Invoke-WintainiumArtifactVerification -DownloadResult $StageInput.Download -SelectedArtifact $decision.SelectedArtifact -OperationId $StageInput.OperationId
                    $verificationSuccessful = if ($null -ne $verification -and $verification.PSObject.Properties['IsSuccessful']) { [bool]$verification.IsSuccessful } else { [string]$verification.Status -eq 'Verified' }
                    & $normalize $verification $verificationSuccessful
                }
            }
            'InstallerSelection' {
                $validation = & $getResult 'ManifestValidation'
                $decision = & $getResult 'UpdateDecision'
                $result = [pscustomobject][ordered]@{
                    Validation=$validation
                    Decision=$decision
                }
                $executor = {
                    param($StageInput, $CancellationToken)
                    $normalize = {
                        param($value, [bool]$successful)
                        if ($null -eq $value) { return [pscustomobject][ordered]@{ IsSuccessful=$successful } }
                        $copy = [ordered]@{}
                        foreach ($property in $value.PSObject.Properties) { $copy[$property.Name] = $property.Value }
                        $copy['IsSuccessful'] = $successful
                        [pscustomobject]$copy
                    }
                    $decision = $StageInput.Decision
                    if ($null -eq $decision -or [string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) { return [pscustomobject][ordered]@{ OperationId=[string]$StageInput.Decision.OperationId; IsSuccessful=$true; Status='Skipped'; ReasonCode='NoUpdateAvailable' } }
                    $selection = Select-WintainiumInstaller -Manifest $StageInput.Validation.Manifest -Artifact $decision.SelectedArtifact -Plugins @($StageInput.Validation.InstallerPlugin)
                    & $normalize $selection ([bool]$selection.IsSelected)
                }
            }
            'Installation' {
                $validation = & $getResult 'ManifestValidation'
                $decision = & $getResult 'UpdateDecision'
                $download = & $getResult 'Download'
                $verification = & $getResult 'Verification'
                $selection = & $getResult 'InstallerSelection'
                $result = [pscustomobject][ordered]@{
                    Validation=$validation
                    Decision=$decision
                    Download=$download
                    Verification=$verification
                    Selection=$selection
                    InstallerTimeoutMilliseconds=$InstallerTimeoutMilliseconds
                    OperationId=[string]$request.OperationId
                }
                $executor = {
                    param($StageInput, $CancellationToken)
                    $normalize = {
                        param($value, [bool]$successful)
                        if ($null -eq $value) { return [pscustomobject][ordered]@{ IsSuccessful=$successful } }
                        $copy = [ordered]@{}
                        foreach ($property in $value.PSObject.Properties) { $copy[$property.Name] = $property.Value }
                        $copy['IsSuccessful'] = $successful
                        [pscustomobject]$copy
                    }
                    $decision = $StageInput.Decision
                    if ($null -eq $decision -or [string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) { return [pscustomobject][ordered]@{ OperationId=$StageInput.OperationId; IsSuccessful=$true; Status='Skipped'; ReasonCode='NoUpdateAvailable' } }
                    if ($null -eq $StageInput.Verification -or [string]$StageInput.Verification.Status -ne 'Verified') { return [pscustomobject][ordered]@{ OperationId=$StageInput.OperationId; IsSuccessful=$false; Status='Blocked'; FailureKind='VerificationRequired'; ErrorMessage='Installation requires successful artifact verification.' } }
                    if ($null -eq $StageInput.Selection -or -not [bool]$StageInput.Selection.IsSelected) { return [pscustomobject][ordered]@{ OperationId=$StageInput.OperationId; IsSuccessful=$false; Status='Blocked'; FailureKind='InstallerSelectionRequired'; ErrorMessage='Installation requires successful installer selection.' } }
                    $installerRequestResult = New-WintainiumInstallerRequest -DownloadResult $StageInput.Download -Manifest $StageInput.Validation.Manifest -OperationId $StageInput.OperationId
                    if (-not $installerRequestResult.IsValid) { return [pscustomobject][ordered]@{ OperationId=$StageInput.OperationId; IsSuccessful=$false; Status='Failed'; FailureKind='InstallerRequestInvalid'; Errors=@($installerRequestResult.Errors) } }
                    $invocationResult = New-WintainiumInstallerInvocation -Selection $StageInput.Selection -Request $installerRequestResult.Request
                    if (-not $invocationResult.IsValid) { return [pscustomobject][ordered]@{ OperationId=$StageInput.OperationId; IsSuccessful=$false; Status='Failed'; FailureKind='InstallerInvocationInvalid'; Error=$invocationResult.Error } }
                    $installation = Invoke-WintainiumInstallerOperation -Invocation $invocationResult.Invocation -TimeoutMilliseconds $StageInput.InstallerTimeoutMilliseconds -CancellationToken $CancellationToken
                    $installationSuccessful = if ($null -ne $installation -and $installation.PSObject.Properties['IsSuccessful']) { [bool]$installation.IsSuccessful } else { [string]$installation.Status -eq 'Completed' }
                    & $normalize $installation $installationSuccessful
                }
            }
            'Reconciliation' {
                $validation = & $getResult 'ManifestValidation'
                $decision = & $getResult 'UpdateDecision'
                $installation = & $getResult 'Installation'
                $result = [pscustomobject][ordered]@{
                    Validation=$validation
                    Decision=$decision
                    Installation=$installation
                    StateRoot=$StateRoot
                    OperationId=[string]$request.OperationId
                }
                $executor = {
                    param($StageInput, $CancellationToken)
                    $normalize = {
                        param($value, [bool]$successful)
                        if ($null -eq $value) { return [pscustomobject][ordered]@{ IsSuccessful=$successful } }
                        $copy = [ordered]@{}
                        foreach ($property in $value.PSObject.Properties) { $copy[$property.Name] = $property.Value }
                        $copy['IsSuccessful'] = $successful
                        [pscustomobject]$copy
                    }
                    $decision = $StageInput.Decision
                    if ($null -eq $decision -or [string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) {
                        return [pscustomobject][ordered]@{
                            OperationId=[string]$StageInput.OperationId
                            IsSuccessful=$true
                            Status='Skipped'
                            ReasonCode='NoUpdateAvailable'
                        }
                    }
                    if ($null -eq $StageInput.Installation -or [string]$StageInput.Installation.Status -ne 'Completed') {
                        return [pscustomobject][ordered]@{
                            OperationId=[string]$StageInput.OperationId
                            IsSuccessful=$false
                            Status='Blocked'
                            FailureKind='InstallationRequired'
                            ErrorMessage='Reconciliation requires a completed installation.'
                        }
                    }

                    $applicationId = [string]$StageInput.Validation.Manifest.Id
                    $priorState = Get-WintainiumInstalledApplicationState -StateRoot $StageInput.StateRoot -ApplicationId $applicationId
                    $reconciliationRequest = [pscustomobject][ordered]@{
                        OperationId=$StageInput.OperationId
                        ApplicationId=$applicationId
                        Manifest=$StageInput.Validation.Manifest
                        PriorState=$priorState
                    }
                    $reconciliation = Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $StageInput.Validation.ReconciliationPlugin -Request $reconciliationRequest
                    $reconciliationSuccessful = [bool]$reconciliation.IsSuccessful
                    $reconciliation = & $normalize $reconciliation $reconciliationSuccessful
                    if (-not $reconciliationSuccessful) {
                        return $reconciliation
                    }

                    $authoritative = Invoke-WintainiumAuthoritativeStateReconciliation -StateRoot $StageInput.StateRoot -OperationId $StageInput.OperationId -ApplicationId $applicationId -ReconciliationResult $reconciliation -PriorState $priorState

                    $reconciliation | Add-Member -NotePropertyName AuthoritativeStateResult -NotePropertyValue $authoritative -Force
                    if (-not [bool]$authoritative.IsSuccessful) {
                        $reconciliation.IsSuccessful = $false
                        $reconciliation.Status = 'Failed'
                        $reconciliation | Add-Member -NotePropertyName FailureKind -NotePropertyValue 'AuthoritativeStateReconciliationFailed' -Force
                        $reconciliation | Add-Member -NotePropertyName Error -NotePropertyValue ([pscustomobject][ordered]@{
                            Code='AuthoritativeStateReconciliationFailed'
                            Message='Authoritative installed state reconciliation failed.'
                            Detail=$authoritative
                        }) -Force
                    }

                    $reconciliation
                }
            }
            default { throw "Unsupported application lifecycle stage '$($stage.Name)'." }
        }

        [pscustomobject][ordered]@{ StageInput=$result; StageExecutor=$executor }
    }

    Invoke-WintainiumOrchestrationLifecycle -Request $request -StagePlan $plan -CancellationContext $cancellationContext -StageFactory $stageFactory
}
