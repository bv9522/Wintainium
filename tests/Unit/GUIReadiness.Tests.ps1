Describe 'Wintainium GUI-facing public boundary' {
    BeforeAll {
        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
        Import-Module -Name $modulePath -Force
    }

    AfterAll {
        Remove-Module -Name Wintainium.Core -Force -ErrorAction SilentlyContinue
    }

    It 'exports exactly the supported presentation-facing commands' {
        $exported = @(Get-Command -Module Wintainium.Core -CommandType Function | Select-Object -ExpandProperty Name | Sort-Object)

        $exported | Should -Be @(
            'Get-WintainiumApplicationInstalledState'
            'Get-WintainiumApplicationRelease'
            'Get-WintainiumManifest'
            'Invoke-WintainiumApplicationOnboarding'
            'Invoke-WintainiumApplicationUpdate'
            'Test-WintainiumApplicationDefinition'
        )
    }

    It 'does not export internal orchestration or installer request helpers' {
        Get-Command -Name 'Get-WintainiumApplicationUpdateDecision' -Module Wintainium.Core -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'New-WintainiumInstallerRequest' -Module Wintainium.Core -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Name 'Invoke-WintainiumOrchestrationLifecycle' -Module Wintainium.Core -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'returns structured array-valued collections from a supported public command' {
        $root = Join-Path -Path $TestDrive -ChildPath 'manifests'
        New-Item -Path $root -ItemType Directory | Out-Null

        $result = Get-WintainiumManifest -Path $root

        $result.PSObject.Properties.Name | Should -Contain 'OperationId'
        $result.PSObject.Properties.Name | Should -Contain 'IsSuccessful'
        $result.PSObject.Properties.Name | Should -Contain 'Candidates'
        $result.PSObject.Properties.Name | Should -Contain 'ManifestPaths'
        $result.PSObject.Properties.Name | Should -Contain 'Manifests'
        $result.PSObject.Properties.Name | Should -Contain 'Errors'
        $result.PSObject.Properties.Name | Should -Contain 'Warnings'
        $result.PSObject.Properties.Name | Should -Contain 'LogEvents'

        $result.OperationId | Should -Not -BeNullOrEmpty
        $result.IsSuccessful | Should -BeTrue
        $result.Candidates.GetType() | Should -Be ([string[]])
        $result.ManifestPaths.GetType() | Should -Be ([string[]])
        $result.Manifests.GetType() | Should -Be ([object[]])
        $result.Errors.GetType() | Should -Be ([object[]])
        $result.Warnings.GetType() | Should -Be ([object[]])
        $result.LogEvents.GetType() | Should -Be ([object[]])
    }

    It 'preserves the release result collection contract when validation fails before discovery' {
        $missingManifest = Join-Path -Path $TestDrive -ChildPath 'missing-release-manifest.json'

        $result = Get-WintainiumApplicationRelease -ManifestPath $missingManifest

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ApplicationDefinitionInvalid'
        $result.Releases.GetType() | Should -Be ([object[]])
        $result.Errors.GetType() | Should -Be ([object[]])
        $result.Warnings.GetType() | Should -Be ([object[]])
        $result.LogEvents.GetType() | Should -Be ([object[]])
    }

    It 'keeps the GUI boundary independent of private orchestration object construction' {
        $contract = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\docs\GUIReadiness.md') -Raw

        $contract | Should -Match 'must not construct'
        $contract | Should -Match 'StagePlan'
        $contract | Should -Match 'StageFactory'
        $contract | Should -Match 'CancellationContext'
        $contract | Should -Match 'must not invoke providers or installers directly'
        $contract | Should -Match 'must not parse terminal formatting'
        $contract | Should -Match 'Unknown.*not.*NotInstalled'
    }
}
