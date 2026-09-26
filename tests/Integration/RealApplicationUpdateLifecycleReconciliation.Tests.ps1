BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:manifestRoot = Join-Path -Path $script:testRoot -ChildPath 'tests/Fixtures/Manifests'
    $script:pluginRoot = Join-Path -Path $script:testRoot -ChildPath 'plugins'
    $script:schemaPath = Join-Path -Path $script:testRoot -ChildPath 'schemas/application-manifest.schema.json'
    Import-Module $script:modulePath -Force
}

Describe 'Real application update lifecycle reconciliation' {
    It 'carries a real 7-Zip Windows reconciliation observation into authoritative installed state' {
        InModuleScope Wintainium.Core -Parameters @{
            ManifestPath = (Join-Path $script:manifestRoot 'windows-7zip-reconciliation.json')
            SchemaPath = $script:schemaPath
            PluginRoot = $script:pluginRoot
        } {
            param($ManifestPath, $SchemaPath, $PluginRoot)

            $importResult = Import-WintainiumManifest -Path $ManifestPath -SchemaPath $SchemaPath
            $importResult.IsValid | Should -BeTrue -Because (($importResult.Errors | ForEach-Object { $_.Message }) -join ' | ')
            $manifest = $importResult.Manifest
            $operationId = [guid]::NewGuid().ToString()

            $provider = [pscustomobject]@{ PluginId = [string]$manifest.Source.pluginId; PluginType = 'Provider'; EntryPoint = 'provider.psm1'; DescriptorPath = '/fixture/provider/plugin.json' }
            $installer = [pscustomobject]@{ PluginId = [string]$manifest.Installer.pluginId; PluginType = 'Installer'; EntryPoint = 'installer.psm1'; DescriptorPath = '/fixture/installer/plugin.json' }
            $reconciliationPlugin = [pscustomobject]@{ PluginId = [string]$manifest.Reconciliation.pluginId; PluginType = 'Reconciliation'; EntryPoint = 'Wintainium.reconciliation.windows-installed-application.psm1'; DescriptorPath = (Join-Path $PluginRoot 'Wintainium.reconciliation.windows-installed-application/plugin.json') }

            $release = [pscustomobject]@{
                OperationId = $operationId
                IsSuccessful = $true
                Status = 'DiscoveryCompleted'
                Releases = @([pscustomobject]@{
                    ReleaseId = 'fixture-release'
                    Version = '99.0.0'
                    Channel = 'stable'
                    Deprecated = $false
                    Artifacts = @([pscustomobject]@{
                        Uri = 'https://example.test/7zip.zip'
                        Format = 'zip'
                        Architecture = 'x64'
                        Hashes = @([pscustomobject]@{ Algorithm = 'SHA256'; Value = ('a' * 64) })
                    })
                })
                Errors = @()
                Warnings = @()
                LogEvents = @()
            }
            $decision = [pscustomobject]@{ OperationId = $operationId; Status = 'UpdateAvailable'; IsUpdateAvailable = $true; SelectedRelease = $release.Releases[0]; SelectedArtifact = $release.Releases[0].Artifacts[0] }
            $download = [pscustomobject]@{ OperationId = $operationId; Status = 'Downloaded'; Uri = 'https://example.test/7zip.zip'; FileName = '7zip.zip'; DestinationPath = (Join-Path $TestDrive '7zip.zip'); BytesWritten = 10 }
            $verification = [pscustomobject]@{ OperationId = $operationId; Status = 'Verified'; IsSuccessful = $true; Algorithm = 'SHA256'; ExpectedHash = ('a' * 64); ActualHash = ('a' * 64); DestinationPath = $download.DestinationPath }
            $selection = [pscustomobject]@{ IsSelected = $true; InstallerPlugin = $installer; ArtifactFormat = 'zip' }
            $installation = [pscustomobject]@{ OperationId = $operationId; Status = 'Completed'; IsSuccessful = $true; ExitCode = 0 }
            $stateRoot = Join-Path $TestDrive 'installed-state'

            Mock New-WintainiumOrchestrationRequest {
                [pscustomobject]@{
                    IsValid = $true
                    Request = [pscustomobject]@{ OperationId = $operationId; ManifestPath = $ManifestPath; MachineArchitecture = 'x64'; DownloadRoot = (Join-Path $TestDrive 'downloads') }
                    Errors = @()
                }
            }
            Mock Test-WintainiumApplicationDefinition {
                [pscustomobject]@{
                    OperationId = $operationId
                    IsValid = $true
                    Manifest = $manifest
                    ProviderPlugin = $provider
                    InstallerPlugin = $installer
                    ReconciliationPlugin = $reconciliationPlugin
                    Errors = @()
                    Warnings = @()
                    LogEvents = @()
                }
            }
            Mock Invoke-WintainiumProviderOperation { $release }
            Set-WintainiumInstalledApplicationState -StateRoot $stateRoot -State ([pscustomobject]@{
                ApplicationId = $manifest.Id
                InstallationState = 'NotInstalled'
                Version = $null
                VersionSource = $null
                Architecture = 'unknown'
                Channel = 'unknown'
                InstallationLocation = $null
            }) | Out-Null
            Mock Get-WintainiumUpdateDecision { $decision }
            Mock New-WintainiumDownloadRequest { [pscustomobject]@{ OperationId = $operationId; UpdateDecision = $decision; SelectedRelease = $decision.SelectedRelease; SelectedArtifact = $decision.SelectedArtifact } }
            Mock Invoke-WintainiumDownload { $download }
            Mock Invoke-WintainiumArtifactVerification { $verification }
            Mock Select-WintainiumInstaller { $selection }
            Mock New-WintainiumInstallerRequest {
                [pscustomobject]@{
                    IsValid = $true
                    Request = [pscustomobject]@{ OperationId = $operationId; DownloadOperationId = $operationId; Manifest = $manifest; Installer = $manifest.Installer; Artifact = [pscustomobject]@{ Path = $download.DestinationPath; Uri = $download.Uri; FileName = $download.FileName } }
                    Errors = @()
                }
            }
            Mock New-WintainiumInstallerInvocation {
                [pscustomobject]@{
                    IsValid = $true
                    Invocation = [pscustomobject]@{ OperationId = $operationId; DownloadOperationId = $operationId; PluginId = $installer.PluginId; PluginModulePath = '/fixture/installer.psm1'; ArtifactPath = $download.DestinationPath; ArtifactFormat = 'zip'; Settings = @{} }
                    Error = $null
                }
            }
            Mock Invoke-WintainiumInstallerOperation { $installation }

            $result = Invoke-WintainiumApplicationUpdateLifecycle -ManifestPath $ManifestPath -StateRoot $stateRoot -MachineArchitecture 'x64' -DownloadRoot (Join-Path $TestDrive 'downloads')

            if (-not $result.IsSuccessful) {
                $errorText = if ($null -ne $result.Error) { [string]$result.Error.Message } else { '<none>' }
                $failedStage = if ($null -ne $result.State.FailedStage) { [string]$result.State.FailedStage.Name } else { '<none>' }
                throw "Real lifecycle reconciliation failed. Error=$errorText; FailedStage=$failedStage"
            }

            $result.IsSuccessful | Should -BeTrue
            $result.OperationId | Should -Be $operationId
            $result.State.Status | Should -Be 'Completed'

            $reconciliationStage = @($result.StageResults | Where-Object { $_.StageName -eq 'Reconciliation' }) | Select-Object -Last 1
            $reconciliationStage | Should -Not -BeNullOrEmpty
            $reconciliation = $reconciliationStage.Execution.Result
            $reconciliation.IsSuccessful | Should -BeTrue
            $reconciliation.Status | Should -Be 'Reconciled'
            $reconciliation.OperationId | Should -Be $operationId
            $reconciliation.Evidence.ApplicationId | Should -Be $manifest.Id
            $reconciliation.Evidence.InstallationState | Should -Be 'Installed'
            $reconciliation.Evidence.EvidenceSource | Should -Be 'WindowsUninstallRegistry'
            $reconciliation.Evidence.Version | Should -Not -BeNullOrEmpty
            $reconciliation.Evidence.VersionSource | Should -Be 'Registry'

            $reconciliation.AuthoritativeStateResult.IsSuccessful | Should -BeTrue
            $reconciliation.AuthoritativeStateResult.Status | Should -Be 'Persisted'
            $reconciliation.AuthoritativeStateResult.Persisted | Should -BeTrue
            $reconciliation.AuthoritativeStateResult.State.ApplicationId | Should -Be $manifest.Id
            $reconciliation.AuthoritativeStateResult.State.InstallationState | Should -Be 'Installed'
            $reconciliation.AuthoritativeStateResult.State.Version | Should -Be $reconciliation.Evidence.Version
            $reconciliation.AuthoritativeStateResult.State.VersionSource | Should -Be 'Registry'
            $reconciliation.AuthoritativeStateResult.State.Architecture | Should -Be 'unknown'

            $persisted = Get-WintainiumApplicationInstalledState -StateRoot $stateRoot -ApplicationId $manifest.Id -OperationId $operationId
            $persisted.IsSuccessful | Should -BeTrue
            $persisted.Status | Should -Be 'Installed'
            $persisted.State.ApplicationId | Should -Be $manifest.Id
            $persisted.State.InstallationState | Should -Be 'Installed'
            $persisted.State.Version | Should -Be $reconciliation.Evidence.Version
            $persisted.State.VersionSource | Should -Be 'Registry'
            $persisted.State.Architecture | Should -Be 'unknown'

        }
    }
}
