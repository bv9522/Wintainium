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
            'Get-WintainiumApplicationUpdateStatus'
            'Get-WintainiumManifest'
            'Invoke-WintainiumApplicationInstall'
            'Invoke-WintainiumApplicationOnboarding'
            'Invoke-WintainiumApplicationReconciliation'
            'Invoke-WintainiumApplicationUpdate'
            'Remove-WintainiumApplication'
            'Set-WintainiumApplicationIconOverride'
            'Set-WintainiumApplicationReconciliationSettings'
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

    It 'returns a structured update decision result at the presentation boundary' {
        $missingManifest = Join-Path -Path $TestDrive -ChildPath 'missing-update-decision-manifest.json'
        $stateRoot = Join-Path -Path $TestDrive -ChildPath 'state'

        $result = Get-WintainiumApplicationUpdateStatus -ManifestPath $missingManifest -StateRoot $stateRoot -MachineArchitecture 'x64'

        $result.PSObject.Properties.Name | Should -Contain 'OperationId'
        $result.PSObject.Properties.Name | Should -Contain 'IsSuccessful'
        $result.PSObject.Properties.Name | Should -Contain 'Status'
        $result.PSObject.Properties.Name | Should -Contain 'Manifest'
        $result.PSObject.Properties.Name | Should -Contain 'InstalledState'
        $result.PSObject.Properties.Name | Should -Contain 'Decision'
        $result.PSObject.Properties.Name | Should -Contain 'Errors'
        $result.PSObject.Properties.Name | Should -Contain 'Warnings'
        $result.PSObject.Properties.Name | Should -Contain 'LogEvents'
        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ProviderDiscoveryUnsuccessful'
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

    It 'wires first-install through the desktop Core client and service boundary' {
        $coreClient = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\Wintainium.Desktop\Engine\WintainiumCoreClient.cs') -Raw
        $installService = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\Wintainium.Desktop\Models\WintainiumApplicationInstallService.cs') -Raw
        $desktopServices = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\Wintainium.Desktop\WintainiumDesktopServices.cs') -Raw

        $coreClient | Should -Match 'Invoke-WintainiumApplicationInstall'
        $installService | Should -Match 'WintainiumApplicationInstallResult'
        $desktopServices | Should -Match 'ApplicationInstall = new WintainiumApplicationInstallService'
    }

    It 'keeps install action state-aware in Application Details' {
        $details = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\Wintainium.Desktop\ApplicationDetailsWindow.xaml.cs') -Raw
        $detailsXaml = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\Wintainium.Desktop\ApplicationDetailsWindow.xaml') -Raw

        $detailsXaml | Should -Match 'x:Name="InstallButton"'
        $details | Should -Match 'WintainiumInstallationState.NotInstalled'
        $details | Should -Match 'InstallButton.Visibility'
        $details | Should -Match 'CheckForUpdatesButton.Visibility'
        $details | Should -Match 'RunUpdateButton.Visibility'
        $details | Should -Match 'WintainiumApplicationInstallService'
    }

    It 'keeps the desktop host install allowlist aligned with the public Core contract' {
        $desktopHost = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\Wintainium.Desktop\Engine\WintainiumPowerShellHost.cs') -Raw
        $contract = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\docs\PublicPowerShellContract.md') -Raw

        $desktopHost | Should -Match 'Invoke-WintainiumApplicationInstall'
        $contract | Should -Match 'Invoke-WintainiumApplicationInstall'
    }

    It 'preserves PowerShell invocation diagnostics when no structured result is returned' {
        $guard = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\Wintainium.Desktop\Models\WintainiumCoreInvocationGuard.cs') -Raw

        $guard | Should -Match 'invocation.Errors'
        $guard | Should -Match 'PowerShell error diagnostics'
    }
    It 'loads the Dashboard collection before starting independent application refreshes' {
        $collectionService = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\Wintainium.Desktop\Models\WintainiumApplicationCollectionService.cs') -Raw
        $mainWindow = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..\src\Wintainium.Desktop\MainWindow.xaml.cs') -Raw

        $collectionService | Should -Match 'RefreshApplicationAsync'
        $mainWindow | Should -Match 'RefreshApplicationStatesAsync'
        $mainWindow | Should -Match 'Task\.WhenAll'
        $mainWindow | Should -Match 'SetApplicationCollection\(result\.Applications\)'
        $mainWindow | Should -Match 'RefreshApplicationAsync'
    }

}
