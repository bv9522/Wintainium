Describe 'Wintainium GUI-facing public boundary' {
    BeforeAll {
        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
        Import-Module -Name $modulePath -Force
    }

    AfterAll {
        Remove-Module -Name Wintainium.Core -Force -ErrorAction SilentlyContinue
    }

    It 'exports exactly the three supported presentation-facing commands' {
        $exported = @(Get-Command -Module Wintainium.Core -CommandType Function | Select-Object -ExpandProperty Name | Sort-Object)

        $exported | Should -Be @(
            'Get-WintainiumApplicationRelease'
            'Get-WintainiumManifest'
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
        $result.Candidates | Should -BeOfType System.Object[]
        $result.ManifestPaths | Should -BeOfType System.String[]
        $result.Manifests | Should -BeOfType System.Object[]
        $result.Errors | Should -BeOfType System.Object[]
        $result.Warnings | Should -BeOfType System.Object[]
        $result.LogEvents | Should -BeOfType System.Object[]
    }

    It 'keeps the GUI boundary independent of private orchestration object construction' {
        $contract = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\docs\GUIReadiness.md') -Raw

        $contract | Should -Match 'must not construct.*StagePlan.*StageFactory.*CancellationContext'
        $contract | Should -Match 'must not.*invoke providers/installers directly'
        $contract | Should -Match 'must not parse terminal formatting'
        $contract | Should -Match 'Unknown.*not.*NotInstalled'
    }
}
