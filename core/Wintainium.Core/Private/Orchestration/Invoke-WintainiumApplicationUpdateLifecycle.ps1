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
        $normalize = {
            param($value, [bool]$successful)
            if ($null -eq $value) { return [pscustomobject][ordered]@{ IsSuccessful=$successful } }
            $copy = [ordered]@{}
            foreach ($property in $value.PSObject.Properties) { $copy[$property.Name] = $property.Value }
            $copy['IsSuccessful'] = $successful
            [pscustomobject]$copy
        }

        $result = [pscustomobject][ordered]@{}
        $executor = $null
        $operationId = [string]$request.OperationId

        switch ([string]$stage.Name) {
            'ManifestValidation' {
                $executor = {
                    param($StageInput, $CancellationToken)
                    $validation = Test-WintainiumApplicationDefinition -ManifestPath $request.ManifestPath -PluginRoot $PluginRoot -SchemaPath $SchemaPath -OperationId $operationId
                    & $normalize $validation ([bool]$validation.IsValid)
                }
            }
            'ReleaseDiscovery' {
                $validation = & $getResult 'ManifestValidation'
                $executor = {
                    param($StageInput, $CancellationToken)
                    if ($null -eq $validation -or -not [bool]$validation.IsSuccessful) { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$false; Status='Blocked'; FailureKind='ManifestValidationRequired'; Errors=@($validation.Errors) } }
                    $manifest = $validation.Manifest
                    $provider = $validation.ProviderPlugin
                    $providerRequest = [pscustomobject][ordered]@{
                        OperationId=$operationId; ApplicationId=[string]$manifest.Id; ProviderId=[string]$provider.PluginId
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
                $executor = {
                    param($StageInput, $CancellationToken)
                    if ($null -eq $release -or -not [bool]$release.IsSuccessful) { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$false; Status='ProviderDiscoveryUnsuccessful'; Errors=if ($null -ne $release) { @($release.Errors) } else { @() }; Warnings=if ($null -ne $release) { @($release.Warnings) } else { @() }; LogEvents=if ($null -ne $release) { @($release.LogEvents) } else { @() } } }
                    $manifest = $validation.Manifest
                    $installedState = Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId ([string]$manifest.Id)
                    $providerResult = [pscustomobject][ordered]@{ IsSuccessful=$true; Status=$release.Status; Releases=@($release.Releases); Errors=@($release.Errors); Warnings=@($release.Warnings); LogEvents=@($release.LogEvents) }
                    $decisionInput = New-WintainiumUpdateDecisionInput -Manifest $manifest -InstalledState $installedState -ProviderResult $providerResult
                    $decision = Get-WintainiumUpdateDecision -UpdateDecisionInput $decisionInput -MachineArchitecture $MachineArchitecture
                    & $normalize $decision $true
                }
            }
            'Download' {
                $decision = & $getResult 'UpdateDecision'
                $executor = {
                    param($StageInput, $CancellationToken)
                    if ($null -eq $decision -or [string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$true; Status='Skipped'; ReasonCode='NoUpdateAvailable' } }
                    $downloadRequest = New-WintainiumDownloadRequest -UpdateDecision $decision -OperationId $operationId
                    $parameters = @{ DownloadRequest=$downloadRequest; DownloadRoot=$DownloadRoot; CancellationToken=$CancellationToken }
                    if ($null -ne $HttpClient) { $parameters.HttpClient=$HttpClient }
                    $downloadResult = Invoke-WintainiumDownload @parameters
                    & $normalize $downloadResult ([string]$downloadResult.Status -eq 'Downloaded')
                }
            }
            'Verification' {
                $decision = & $getResult 'UpdateDecision'
                $download = & $getResult 'Download'
                $executor = {
                    param($StageInput, $CancellationToken)
                    if ($null -eq $decision -or [string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$true; Status='Skipped'; ReasonCode='NoUpdateAvailable' } }
                    $verification = Invoke-WintainiumArtifactVerification -DownloadResult $download -SelectedArtifact $decision.SelectedArtifact -OperationId $operationId
                    & $normalize $verification ([string]$verification.Status -eq 'Verified')
                }
            }
            'InstallerSelection' {
                $validation = & $getResult 'ManifestValidation'
                $decision = & $getResult 'UpdateDecision'
                $executor = {
                    param($StageInput, $CancellationToken)
                    if ($null -eq $decision -or [string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$true; Status='Skipped'; ReasonCode='NoUpdateAvailable' } }
                    $selection = Select-WintainiumInstaller -Manifest $validation.Manifest -Artifact $decision.SelectedArtifact -Plugins @($validation.InstallerPlugin)
                    & $normalize $selection ([bool]$selection.IsSelected)
                }
            }
            'Installation' {
                $validation = & $getResult 'ManifestValidation'
                $decision = & $getResult 'UpdateDecision'
                $download = & $getResult 'Download'
                $verification = & $getResult 'Verification'
                $selection = & $getResult 'InstallerSelection'
                $executor = {
                    param($StageInput, $CancellationToken)
                    if ($null -eq $decision -or [string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$true; Status='Skipped'; ReasonCode='NoUpdateAvailable' } }
                    if ($null -eq $verification -or [string]$verification.Status -ne 'Verified') { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$false; Status='Blocked'; FailureKind='VerificationRequired'; ErrorMessage='Installation requires successful artifact verification.' } }
                    if ($null -eq $selection -or -not [bool]$selection.IsSelected) { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$false; Status='Blocked'; FailureKind='InstallerSelectionRequired'; ErrorMessage='Installation requires successful installer selection.' } }
                    $installerRequestResult = New-WintainiumInstallerRequest -DownloadResult $download -Manifest $validation.Manifest -OperationId $operationId
                    if (-not $installerRequestResult.IsValid) { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$false; Status='Failed'; FailureKind='InstallerRequestInvalid'; Errors=@($installerRequestResult.Errors) } }
                    $invocationResult = New-WintainiumInstallerInvocation -Selection $selection -Request $installerRequestResult.Request
                    if (-not $invocationResult.IsValid) { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$false; Status='Failed'; FailureKind='InstallerInvocationInvalid'; Error=$invocationResult.Error } }
                    $installation = Invoke-WintainiumInstallerOperation -Invocation $invocationResult.Invocation -TimeoutMilliseconds $InstallerTimeoutMilliseconds -CancellationToken $CancellationToken
                    & $normalize $installation ([string]$installation.Status -eq 'Completed')
                }
            }
            'Reconciliation' {
                $validation = & $getResult 'ManifestValidation'
                $decision = & $getResult 'UpdateDecision'
                $installation = & $getResult 'Installation'
                $executor = {
                    param($StageInput, $CancellationToken)
                    if ($null -eq $decision -or [string]$decision.Status -ne 'UpdateAvailable' -or -not [bool]$decision.IsUpdateAvailable) { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$true; Status='Skipped'; ReasonCode='NoUpdateAvailable' } }
                    if ($null -eq $installation -or [string]$installation.Status -ne 'Completed') { return [pscustomobject][ordered]@{ OperationId=$operationId; IsSuccessful=$false; Status='Blocked'; FailureKind='InstallationRequired'; ErrorMessage='Reconciliation requires a completed installation.' } }
                    $applicationId = [string]$validation.Manifest.Id
                    $priorState = Get-WintainiumInstalledApplicationState -StateRoot $StateRoot -ApplicationId $applicationId
                    $reconciliationRequest = [pscustomobject][ordered]@{ OperationId=$operationId; ApplicationId=$applicationId; Manifest=$validation.Manifest; PriorState=$priorState }
                    $reconciliation = Invoke-WintainiumReconciliationOperation -ReconciliationPlugin $validation.ReconciliationPlugin -Request $reconciliationRequest
                    & $normalize $reconciliation ([bool]$reconciliation.IsSuccessful)
                }
            }
            default { throw "Unsupported application lifecycle stage '$($stage.Name)'." }
        }

        [pscustomobject][ordered]@{ StageInput=$result; StageExecutor=$executor }
    }

    Invoke-WintainiumOrchestrationLifecycle -Request $request -StagePlan $plan -CancellationContext $cancellationContext -StageFactory $stageFactory
}
