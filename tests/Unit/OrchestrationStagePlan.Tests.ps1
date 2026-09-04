$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium orchestration stage plan' {
    BeforeAll {
        $manifestPath = Join-Path $TestDrive 'application.wintainium.json'
        $downloadRoot = Join-Path $TestDrive 'downloads'

        $request = InModuleScope Wintainium.Core -Parameters @{
            ManifestPath = $manifestPath
            MachineArchitecture = 'x64'
            DownloadRoot = $downloadRoot
        } {
            param($ManifestPath, $MachineArchitecture, $DownloadRoot)
            New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
        }

        $validRequest = $request.Request
    }

    It 'creates the required deterministic lifecycle in order' {
        $result = InModuleScope Wintainium.Core -Parameters @{ OrchestrationRequest = $validRequest } {
            param($OrchestrationRequest)
            New-WintainiumOrchestrationStagePlan -OrchestrationRequest $OrchestrationRequest
        }

        $result.IsValid | Should -BeTrue
        $result.Errors | Should -HaveCount 0
        @($result.Plan.Stages).Count | Should -Be 7
        @($result.Plan.Stages.Name) | Should -Be @(
            'ManifestValidation'
            'ReleaseDiscovery'
            'UpdateDecision'
            'Download'
            'Verification'
            'InstallerSelection'
            'Installation'
        )
        @($result.Plan.Stages.Sequence) | Should -Be @(1, 2, 3, 4, 5, 6, 7)
        @($result.Plan.Stages.Required) | Should -Be @( $true, $true, $true, $true, $true, $true, $true )
    }

    It 'preserves the parent orchestration context without creating a second operation identifier' {
        $result = InModuleScope Wintainium.Core -Parameters @{ OrchestrationRequest = $validRequest } {
            param($OrchestrationRequest)
            New-WintainiumOrchestrationStagePlan -OrchestrationRequest $OrchestrationRequest
        }

        $result.Plan.OperationId | Should -Be $validRequest.OperationId
        $result.Plan.ManifestPath | Should -Be $validRequest.ManifestPath
        $result.Plan.MachineArchitecture | Should -Be $validRequest.MachineArchitecture
        $result.Plan.DownloadRoot | Should -Be $validRequest.DownloadRoot
    }

    It 'rejects a missing orchestration request structurally' {
        $result = InModuleScope Wintainium.Core {
            New-WintainiumOrchestrationStagePlan -OrchestrationRequest $null
        }

        $result.IsValid | Should -BeFalse
        $result.Plan | Should -BeNullOrEmpty
        $result.Errors | Should -HaveCount 1
        $result.Errors[0].Code | Should -Be 'OrchestrationStagePlanRequestMissing'
    }

    It 'rejects a request missing required context properties' {
        $invalidRequest = [pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            ManifestPath = 'C:\manifests\application.wintainium.json'
            MachineArchitecture = 'x64'
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ OrchestrationRequest = $invalidRequest } {
            param($OrchestrationRequest)
            New-WintainiumOrchestrationStagePlan -OrchestrationRequest $OrchestrationRequest
        }

        $result.IsValid | Should -BeFalse
        $result.Plan | Should -BeNullOrEmpty
        $result.Errors | Should -HaveCount 1
        $result.Errors[0].Code | Should -Be 'OrchestrationStagePlanRequestPropertyMissing'
        $result.Errors[0].Message | Should -Match 'DownloadRoot'
    }

    It 'rejects a malformed parent operation identifier' {
        $invalidRequest = [pscustomobject]@{
            OperationId = 'not-a-guid'
            ManifestPath = 'C:\manifests\application.wintainium.json'
            MachineArchitecture = 'x64'
            DownloadRoot = 'C:\downloads'
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ OrchestrationRequest = $invalidRequest } {
            param($OrchestrationRequest)
            New-WintainiumOrchestrationStagePlan -OrchestrationRequest $OrchestrationRequest
        }

        $result.IsValid | Should -BeFalse
        $result.Plan | Should -BeNullOrEmpty
        $result.Errors | Should -HaveCount 1
        $result.Errors[0].Code | Should -Be 'OrchestrationStagePlanOperationIdInvalid'
    }

    It 'does not require stage-owned resources to exist' {
        $missingRequest = [pscustomobject]@{
            OperationId = [guid]::NewGuid().ToString()
            ManifestPath = 'C:\missing\application.wintainium.json'
            MachineArchitecture = 'x64'
            DownloadRoot = 'C:\not-created-yet\downloads'
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ OrchestrationRequest = $missingRequest } {
            param($OrchestrationRequest)
            New-WintainiumOrchestrationStagePlan -OrchestrationRequest $OrchestrationRequest
        }

        $result.IsValid | Should -BeTrue
        $result.Plan.Stages[0].Name | Should -Be 'ManifestValidation'
        $result.Plan.Stages[4].Name | Should -Be 'Verification'
    }

    It 'keeps verification as a required stage between download and installer selection' {
        $result = InModuleScope Wintainium.Core -Parameters @{ OrchestrationRequest = $validRequest } {
            param($OrchestrationRequest)
            New-WintainiumOrchestrationStagePlan -OrchestrationRequest $OrchestrationRequest
        }

        $result.Plan.Stages[3].Name | Should -Be 'Download'
        $result.Plan.Stages[4].Name | Should -Be 'Verification'
        $result.Plan.Stages[4].Required | Should -BeTrue
        $result.Plan.Stages[5].Name | Should -Be 'InstallerSelection'
    }
}
