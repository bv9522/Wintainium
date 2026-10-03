function ConvertTo-WintainiumPublicApplicationLifecycleResult {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [psobject]$LifecycleResult
    )

    $operationId = if ($null -ne $LifecycleResult.PSObject.Properties['OperationId']) { [string]$LifecycleResult.OperationId } else { $null }
    $isSuccessful = if ($null -ne $LifecycleResult.PSObject.Properties['IsSuccessful']) { [bool]$LifecycleResult.IsSuccessful } else { $false }
    $wasCancelled = if ($null -ne $LifecycleResult.PSObject.Properties['WasCancelled']) { [bool]$LifecycleResult.WasCancelled } else { $false }
    $status = if ($wasCancelled) { 'Cancelled' } elseif ($isSuccessful) { 'Completed' } else { 'Failed' }

    $applicationId = $null
    $stages = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $logEvents = [System.Collections.Generic.List[object]]::new()

    foreach ($item in @($LifecycleResult.StageResults)) {
        if ($null -eq $item) { continue }
        $execution = if ($null -ne $item.PSObject.Properties['Execution']) { $item.Execution } else { $null }
        $stage = if ($null -ne $item.PSObject.Properties['Stage']) { $item.Stage } else { $null }
        $result = if ($null -ne $execution -and $execution.PSObject.Properties['Result']) { $execution.Result } else { $null }
        if ($null -eq $stage) { $stage = $item }

        $sequence = if ($null -ne $stage.PSObject.Properties['Sequence']) { [int]$stage.Sequence } elseif ($null -ne $item.PSObject.Properties['StageSequence']) { [int]$item.StageSequence } else { 0 }
        $name = if ($null -ne $stage.PSObject.Properties['Name']) { [string]$stage.Name } elseif ($null -ne $item.PSObject.Properties['StageName']) { [string]$item.StageName } else { $null }
        $stageStatus = if ($null -ne $result -and $result.PSObject.Properties['Status']) { [string]$result.Status } elseif ($null -ne $execution -and $execution.PSObject.Properties['Status']) { [string]$execution.Status } else { $null }
        $stageSuccessful = if ($null -ne $result -and $result.PSObject.Properties['IsSuccessful']) { [bool]$result.IsSuccessful } elseif ($null -ne $execution -and $execution.PSObject.Properties['IsSuccessful']) { [bool]$execution.IsSuccessful } else { $false }
        $stageCancelled = if ($null -ne $execution -and $execution.PSObject.Properties['WasCancelled']) { [bool]$execution.WasCancelled } else { $false }
        $reasonCode = if ($null -ne $result -and $result.PSObject.Properties['ReasonCode']) { [string]$result.ReasonCode } else { $null }
        $reason = if ($null -ne $result -and $result.PSObject.Properties['Reason']) { [string]$result.Reason } else { $null }

        $stageErrorCandidates = [System.Collections.Generic.List[object]]::new()
        if ($null -ne $result -and $result.PSObject.Properties['Error'] -and $null -ne $result.Error) { $stageErrorCandidates.Add($result.Error) }
        if ($null -ne $execution -and $execution.PSObject.Properties['Error'] -and $null -ne $execution.Error) {
            $stageErrorCandidates.Add($execution.Error)
            if ($execution.Error.PSObject.Properties['Detail'] -and $null -ne $execution.Error.Detail) { $stageErrorCandidates.Add($execution.Error.Detail) }
        }
        if ($null -ne $result -and ($result.PSObject.Properties['FailureKind'] -or $result.PSObject.Properties['ErrorMessage'])) {
            $failureKind = if ($result.PSObject.Properties['FailureKind']) { [string]$result.FailureKind } else { $null }
            $errorMessage = if ($result.PSObject.Properties['ErrorMessage']) { [string]$result.ErrorMessage } else { $null }
            if (-not [string]::IsNullOrWhiteSpace($failureKind) -or -not [string]::IsNullOrWhiteSpace($errorMessage)) {
                $stageErrorCandidates.Add([pscustomobject][ordered]@{ Code = if (-not [string]::IsNullOrWhiteSpace($failureKind)) { $failureKind } else { 'OrchestrationStageStructuredFailure' }; Message = if (-not [string]::IsNullOrWhiteSpace($errorMessage)) { $errorMessage } else { "The stage reported failure kind '$failureKind'." }; FailureKind = $failureKind; ErrorMessage = $errorMessage })
            }
        }
        if ($null -ne $item.PSObject.Properties['Error'] -and $null -ne $item.Error) { $stageErrorCandidates.Add($item.Error) }

        $stageError = $stageErrorCandidates | Where-Object {
            $message = if ($_.PSObject.Properties['Message']) { [string]$_.Message } else { $null }
            $code = if ($_.PSObject.Properties['Code']) { [string]$_.Code } else { $null }
            -not ([string]::Equals($code, 'OrchestrationStageExecutionFailed', [System.StringComparison]::OrdinalIgnoreCase) -or ([string]::Equals($code, 'OrchestrationStageStructuredFailure', [System.StringComparison]::OrdinalIgnoreCase) -and [string]::Equals($message, 'The stage returned a structured unsuccessful result.', [System.StringComparison]::OrdinalIgnoreCase)))
        } | Select-Object -First 1
        if ($null -eq $stageError -and $stageErrorCandidates.Count -gt 0) { $stageError = $stageErrorCandidates[0] }

        if ($null -ne $stageError -and -not $stageError.PSObject.Properties['Code'] -and -not $stageError.PSObject.Properties['Message']) {
            $detailProperties = @($stageError.PSObject.Properties.Name)
            $stageError = [pscustomobject][ordered]@{
                Code = if ($stageError.PSObject.Properties['FailureKind'] -and -not [string]::IsNullOrWhiteSpace([string]$stageError.FailureKind)) { [string]$stageError.FailureKind } else { 'OrchestrationStageStructuredFailure' }
                Message = if ($stageError.PSObject.Properties['ErrorMessage'] -and -not [string]::IsNullOrWhiteSpace([string]$stageError.ErrorMessage)) { [string]$stageError.ErrorMessage } else { "The stage returned a structured unsuccessful result without a usable error message. Result properties: $($detailProperties -join ', ')." }
                FailureKind = if ($stageError.PSObject.Properties['FailureKind']) { [string]$stageError.FailureKind } else { $null }
                ErrorMessage = if ($stageError.PSObject.Properties['ErrorMessage']) { [string]$stageError.ErrorMessage } else { $null }
                ResultProperties = $detailProperties
                Detail = $stageError
            }
        }

        if ($null -ne $stageError) {
            $messageProperty = $stageError.PSObject.Properties['Message']
            $errorMessageProperty = $stageError.PSObject.Properties['ErrorMessage']
            $failureKindProperty = $stageError.PSObject.Properties['FailureKind']
            $hasErrorMessage = $null -ne $errorMessageProperty -and -not [string]::IsNullOrWhiteSpace([string]$errorMessageProperty.Value)
            $hasFailureKind = $null -ne $failureKindProperty -and -not [string]::IsNullOrWhiteSpace([string]$failureKindProperty.Value)
            $hasUsableMessage = $null -ne $messageProperty -and -not [string]::IsNullOrWhiteSpace([string]$messageProperty.Value)
            $isGenericWrapperCode = $stageError.PSObject.Properties['Code'] -and ([string]::Equals([string]$stageError.Code, 'OrchestrationStageExecutionFailed', [System.StringComparison]::OrdinalIgnoreCase) -or [string]::Equals([string]$stageError.Code, 'OrchestrationStageStructuredFailure', [System.StringComparison]::OrdinalIgnoreCase))
            if ($hasErrorMessage -and ($hasFailureKind -or -not $hasUsableMessage -or $isGenericWrapperCode)) {
                $stageError = [pscustomobject][ordered]@{ Code = if ($hasFailureKind) { [string]$failureKindProperty.Value } elseif ($stageError.PSObject.Properties['Code'] -and -not [string]::IsNullOrWhiteSpace([string]$stageError.Code)) { [string]$stageError.Code } else { 'OrchestrationStageStructuredFailure' }; Message = [string]$errorMessageProperty.Value; FailureKind = if ($hasFailureKind) { [string]$failureKindProperty.Value } else { $null }; ErrorMessage = [string]$errorMessageProperty.Value }
            }
        }

        if ($null -eq $applicationId -and $null -ne $result -and $result.PSObject.Properties['Manifest'] -and $null -ne $result.Manifest -and $result.Manifest.PSObject.Properties['Id']) { $applicationId = [string]$result.Manifest.Id }

        $stages.Add([pscustomobject][ordered]@{
            Sequence = $sequence
            Name = $name
            Status = $stageStatus
            ReasonCode = $reasonCode
            Reason = $reason
            IsSuccessful = $stageSuccessful
            WasCancelled = $stageCancelled
            Error = $stageError
        })

        if ($null -ne $result) {
            foreach ($collectionName in @('Errors','Warnings','LogEvents')) {
                if ($result.PSObject.Properties[$collectionName]) {
                    foreach ($entry in @($result.$collectionName)) {
                        if ($null -ne $entry) {
                            switch ($collectionName) { 'Errors' { $errors.Add($entry) }; 'Warnings' { $warnings.Add($entry) }; 'LogEvents' { $logEvents.Add($entry) } }
                        }
                    }
                }
            }
        }

        if ($null -ne $stageError) { $errors.Add($stageError) }
        if ($stageStatus -in @('DecisionIndeterminate','NoInstallableRelease','ProviderDiscoveryUnsuccessful') -and (-not [string]::IsNullOrWhiteSpace($reasonCode) -or -not [string]::IsNullOrWhiteSpace($reason))) {
            $warnings.Add([pscustomobject][ordered]@{
                Code = if (-not [string]::IsNullOrWhiteSpace($reasonCode)) { $reasonCode } else { 'LifecycleDecisionDiagnostic' }
                Message = if (-not [string]::IsNullOrWhiteSpace($reason)) { "$name`: $reason" } else { "$name reported status '$stageStatus'." }
            })
        }
    }

    if ($null -ne $LifecycleResult.PSObject.Properties['Error'] -and $null -ne $LifecycleResult.Error) { $errors.Add($LifecycleResult.Error) }

    $troubleshootingDiagnostics = [System.Collections.Generic.List[object]]::new()
    if (-not $isSuccessful -and -not $wasCancelled) {
        foreach ($item in @($LifecycleResult.StageResults)) {
            if ($null -eq $item) { continue }
            $execution = if ($null -ne $item.PSObject.Properties['Execution']) { $item.Execution } else { $null }
            $stage = if ($null -ne $item.PSObject.Properties['Stage']) { $item.Stage } else { $item }
            $result = if ($null -ne $execution -and $execution.PSObject.Properties['Result']) { $execution.Result } else { $null }
            if ($null -eq $result) { continue }
            $stageName = if ($stage.PSObject.Properties['Name']) { [string]$stage.Name } elseif ($item.PSObject.Properties['StageName']) { [string]$item.StageName } else { 'Unknown' }
            switch ($stageName) {
                'ReleaseDiscovery' {
                    $providerId = if ($result.PSObject.Properties['ProviderId']) { [string]$result.ProviderId } else { $null }
                    $releaseCount = if ($result.PSObject.Properties['Releases']) { @($result.Releases).Count } else { 0 }
                    $message = if ([string]::IsNullOrWhiteSpace($providerId)) { "Release Discovery: $releaseCount release(s) reported." } else { "Release Discovery: provider '$providerId' reported $releaseCount release(s)." }
                    $troubleshootingDiagnostics.Add([pscustomobject][ordered]@{ Code='InstallDiagnostic.ReleaseDiscovery'; Message=$message })
                }
                'UpdateDecision' {
                    $selectedRelease = if ($result.PSObject.Properties['SelectedRelease']) { $result.SelectedRelease } else { $null }
                    $selectedArtifact = if ($result.PSObject.Properties['SelectedArtifact']) { $result.SelectedArtifact } else { $null }
                    $version = if ($null -ne $selectedRelease -and $selectedRelease.PSObject.Properties['Version']) { [string]$selectedRelease.Version } else { $null }
                    $fileName = if ($null -ne $selectedArtifact -and $selectedArtifact.PSObject.Properties['FileName']) { [string]$selectedArtifact.FileName } else { $null }
                    $format = if ($null -ne $selectedArtifact -and $selectedArtifact.PSObject.Properties['Format']) { [string]$selectedArtifact.Format } else { $null }
                    $architecture = if ($null -ne $selectedArtifact -and $selectedArtifact.PSObject.Properties['Architecture']) { [string]$selectedArtifact.Architecture } else { $null }
                    $hashCount = if ($null -ne $selectedArtifact -and $selectedArtifact.PSObject.Properties['Hashes'] -and $null -ne $selectedArtifact.Hashes) { @($selectedArtifact.Hashes).Count } else { 0 }
                    $hashAlgorithms = if ($hashCount -gt 0) { @($selectedArtifact.Hashes | ForEach-Object { if ($_.PSObject.Properties['Algorithm']) { [string]$_.Algorithm } }) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique } else { @() }
                    $parts = [System.Collections.Generic.List[string]]::new()
                    if (-not [string]::IsNullOrWhiteSpace($version)) { $parts.Add("release $version") }
                    if (-not [string]::IsNullOrWhiteSpace($fileName)) { $parts.Add("artifact '$fileName'") }
                    if (-not [string]::IsNullOrWhiteSpace($format)) { $parts.Add("format $format") }
                    if (-not [string]::IsNullOrWhiteSpace($architecture)) { $parts.Add("architecture $architecture") }
                    $parts.Add($(if ($hashCount -eq 0) { 'verification hashes: 0' } else { "verification hashes: $hashCount ($($hashAlgorithms -join ', '))" }))
                    $troubleshootingDiagnostics.Add([pscustomobject][ordered]@{ Code='InstallDiagnostic.InstallDecision'; Message="Install Decision: $($parts -join '; ')." })
                }
                'Download' {
                    $status = if ($result.PSObject.Properties['Status']) { [string]$result.Status } else { 'Unknown' }
                    $fileName = if ($result.PSObject.Properties['FileName']) { [string]$result.FileName } else { $null }
                    $destination = if ($result.PSObject.Properties['DestinationPath']) { [string]$result.DestinationPath } else { $null }
                    $parts = [System.Collections.Generic.List[string]]::new(); $parts.Add("status $status")
                    if (-not [string]::IsNullOrWhiteSpace($fileName)) { $parts.Add("file '$fileName'") }
                    if (-not [string]::IsNullOrWhiteSpace($destination)) { $parts.Add("destination '$destination'") }
                    if ($result.PSObject.Properties['BytesWritten']) { $parts.Add("bytes $([long]$result.BytesWritten)") }
                    $troubleshootingDiagnostics.Add([pscustomobject][ordered]@{ Code='InstallDiagnostic.Download'; Message="Download: $($parts -join '; ')." })
                }
                'Verification' {
                    $status = if ($result.PSObject.Properties['Status']) { [string]$result.Status } else { 'Unknown' }
                    $algorithm = if ($result.PSObject.Properties['Algorithm']) { [string]$result.Algorithm } else { $null }
                    $expected = if ($result.PSObject.Properties['ExpectedHash']) { [string]$result.ExpectedHash } else { $null }
                    $actual = if ($result.PSObject.Properties['ActualHash']) { [string]$result.ActualHash } else { $null }
                    $failureKind = if ($result.PSObject.Properties['FailureKind']) { [string]$result.FailureKind } else { $null }
                    $parts = [System.Collections.Generic.List[string]]::new(); $parts.Add("status $status")
                    if (-not [string]::IsNullOrWhiteSpace($algorithm)) { $parts.Add("algorithm $algorithm") }
                    if (-not [string]::IsNullOrWhiteSpace($failureKind)) { $parts.Add("failure $failureKind") }
                    $parts.Add("expected SHA256 $(if ([string]::IsNullOrWhiteSpace($expected)) { 'not available' } else { $expected })")
                    $parts.Add("actual SHA256 $(if ([string]::IsNullOrWhiteSpace($actual)) { 'not available' } else { $actual })")
                    $troubleshootingDiagnostics.Add([pscustomobject][ordered]@{ Code='InstallDiagnostic.Verification'; Message="Verification: $($parts -join '; ')." })
                }
                'InstallerSelection' {
                    $pluginId = if ($result.PSObject.Properties['InstallerPlugin'] -and $null -ne $result.InstallerPlugin -and $result.InstallerPlugin.PSObject.Properties['PluginId']) { [string]$result.InstallerPlugin.PluginId } else { $null }
                    $format = if ($result.PSObject.Properties['ArtifactFormat']) { [string]$result.ArtifactFormat } else { $null }
                    $parts = [System.Collections.Generic.List[string]]::new()
                    if (-not [string]::IsNullOrWhiteSpace($pluginId)) { $parts.Add("installer '$pluginId'") }
                    if (-not [string]::IsNullOrWhiteSpace($format)) { $parts.Add("format $format") }
                    if ($parts.Count -eq 0) { $parts.Add('no installer selection details were reported') }
                    $troubleshootingDiagnostics.Add([pscustomobject][ordered]@{ Code='InstallDiagnostic.InstallerSelection'; Message="Installer Selection: $($parts -join '; ')." })
                }
            }
        }
    }

    [pscustomobject][ordered]@{
        OperationId = $operationId
        IsSuccessful = $isSuccessful
        WasCancelled = $wasCancelled
        Status = $status
        ApplicationId = $applicationId
        Stages = @($stages.ToArray())
        Errors = @($errors.ToArray())
        Warnings = @($warnings.ToArray())
        LogEvents = @($logEvents.ToArray())
        TroubleshootingDiagnostics = @($troubleshootingDiagnostics.ToArray())
        Error = if ($null -ne $LifecycleResult.PSObject.Properties['Error']) { $LifecycleResult.Error } else { $null }
    }
}