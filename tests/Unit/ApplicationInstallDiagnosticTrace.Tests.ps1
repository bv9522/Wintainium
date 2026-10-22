BeforeAll {
    $script:repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path $script:repoRoot 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force
}

Describe 'Wintainium install diagnostic trace' {
    It 'surfaces structured provider discovery trace and avoids duplicate no-installable-release warnings' {
        InModuleScope Wintainium.Core {
            $operationId = '00000000-0000-0000-0000-000000000201'
            $providerEvent = [pscustomobject]@{
                OperationId = $operationId
                Severity = 'Warning'
                Component = 'OfficialDownloadPageProvider'
                EventName = 'ReleaseDiscoveryParsingCompleted'
                Message = 'Official download page parsing completed.'
                Context = @{
                    RequestedUrl = 'https://example.test/downloads'
                    FinalUrl = 'https://example.test/downloads'
                    HttpStatusCode = 200
                    ContentType = 'text/html'
                    SectionCandidateCount = 0
                    DownloadArtifactCandidateCount = 3
                    ParsedArtifactCount = 0
                    ParsedReleaseCount = 0
                    Outcome = 'NoReleaseSectionCandidates'
                    FailureStage = 'Parsing'
                }
            }
            $releaseResult = [pscustomobject]@{
                OperationId = $operationId
                IsSuccessful = $true
                Status = 'NoReleasesFound'
                ProviderId = 'Wintainium.provider.official-download-page'
                Releases = @()
                Errors = @()
                Warnings = @()
                LogEvents = @($providerEvent)
            }
            $decisionResult = [pscustomobject]@{
                OperationId = $operationId
                IsSuccessful = $true
                Status = 'NoInstallableRelease'
                ReasonCode = 'NoSelectableArtifact'
                Reason = 'No discovered release has a selectable artifact for this machine.'
                SelectedArtifact = $null
                ReleaseEligibility = [pscustomobject]@{ Observations = @() }
            }
            $lifecycle = [pscustomobject]@{
                OperationId = $operationId
                IsSuccessful = $true
                WasCancelled = $false
                StageResults = @(
                    [pscustomobject]@{
                        StageName = 'ReleaseDiscovery'
                        Stage = [pscustomobject]@{ Sequence = 2; Name = 'ReleaseDiscovery' }
                        Execution = [pscustomobject]@{ IsSuccessful = $true; Result = $releaseResult }
                    },
                    [pscustomobject]@{
                        StageName = 'UpdateDecision'
                        Stage = [pscustomobject]@{ Sequence = 3; Name = 'UpdateDecision' }
                        Execution = [pscustomobject]@{ IsSuccessful = $true; Result = $decisionResult }
                    }
                )
                Error = $null
            }

            $result = ConvertTo-WintainiumPublicApplicationLifecycleResult -LifecycleResult $lifecycle
            $trace = @($result.TroubleshootingDiagnostics | Where-Object Code -eq 'InstallDiagnostic.ReleaseDiscoveryTrace')

            $trace.Count | Should -Be 1
            $trace[0].Message | Should -Match 'NoReleaseSectionCandidates'
            $trace[0].Message | Should -Match 'SectionCandidateCount=0'
            @($result.Warnings | Where-Object Code -eq 'NoSelectableArtifact').Count | Should -Be 0
        }
    }


    It 'preserves the first concrete stage failure as the public primary error' {
        InModuleScope Wintainium.Core {
            $operationId = '00000000-0000-0000-0000-000000000202'
            $specificError = [pscustomobject][ordered]@{
                Code = 'VerificationMetadataMissing'
                Message = 'The selected artifact contains no SHA256 verification evidence.'
            }
            $genericError = [pscustomobject][ordered]@{
                Code = 'OrchestrationStageExecutionFailed'
                Message = 'A lifecycle stage failed.'
            }
            $verificationResult = [pscustomobject][ordered]@{
                IsSuccessful = $false
                Status = 'Failed'
                ReasonCode = 'VerificationMetadataMissing'
                Reason = 'SHA256 verification evidence is unavailable.'
                Error = $specificError
                Errors = @()
                Warnings = @()
                LogEvents = @()
            }
            $lifecycle = [pscustomobject][ordered]@{
                OperationId = $operationId
                IsSuccessful = $false
                WasCancelled = $false
                StageResults = @(
                    [pscustomobject][ordered]@{
                        StageName = 'Verification'
                        Stage = [pscustomobject][ordered]@{ Sequence = 5; Name = 'Verification' }
                        Execution = [pscustomobject][ordered]@{
                            IsSuccessful = $false
                            Status = 'Failed'
                            Result = $verificationResult
                            Error = $genericError
                            ElapsedMilliseconds = 42
                        }
                    }
                )
                Error = $genericError
            }

            $result = ConvertTo-WintainiumPublicApplicationLifecycleResult -LifecycleResult $lifecycle

            $result.Status | Should -Be 'Failed'
            $result.Error.Code | Should -Be 'VerificationMetadataMissing'
            $result.Stages[0].ReasonCode | Should -Be 'VerificationMetadataMissing'
            $result.Stages[0].Reason | Should -Be 'SHA256 verification evidence is unavailable.'
            @($result.Errors | Where-Object Code -eq 'VerificationMetadataMissing').Count | Should -BeGreaterThan 0
        }
    }
}
