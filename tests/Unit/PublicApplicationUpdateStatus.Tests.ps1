BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force
}

Describe 'Wintainium public application update status command' {
    It 'is exposed as a documented public Core command' {
        (Get-Command Get-WintainiumApplicationUpdateStatus -Module Wintainium.Core).CommandType | Should -Be 'Function'
    }

    It 'projects the authoritative installed state and update decision for presentation clients' {
        InModuleScope Wintainium.Core {
            Mock Get-WintainiumApplicationUpdateDecision {
                [pscustomobject][ordered]@{
                    OperationId = 'operation-update-status'
                    IsSuccessful = $true
                    Status = 'UpdateAvailable'
                    Manifest = [pscustomobject]@{ Id = 'example.app'; Name = 'Example' }
                    InstalledState = [pscustomobject][ordered]@{
                        ApplicationId = 'example.app'
                        InstallationState = 'Installed'
                        Version = '26.02'
                        VersionSource = 'Registry'
                        Architecture = 'x64'
                        Channel = 'stable'
                        InstallationLocation = 'C:\Program Files\Example'
                    }
                    Decision = [pscustomobject][ordered]@{
                        IsUpdateAvailable = $true
                        ReasonCode = 'NewerReleaseAvailable'
                        Reason = 'A newer release is available.'
                        IsDeterministic = $true
                        SelectedRelease = [pscustomobject][ordered]@{
                            ReleaseId = 'release-26.03'
                            Version = '26.03'
                            Channel = 'stable'
                            PublishedAt = '2026-09-27T00:00:00Z'
                        }
                    }
                    Errors = @()
                    Warnings = @()
                    LogEvents = @()
                }
            }

            $result = Get-WintainiumApplicationUpdateStatus -ManifestPath 'C:\manifest.json' -StateRoot 'C:\state' -MachineArchitecture 'x64'

            $result.IsSuccessful | Should -BeTrue
            $result.Status | Should -Be 'UpdateAvailable'
            $result.InstalledState.ApplicationId | Should -Be 'example.app'
            $result.InstalledState.InstallationState | Should -Be 'Installed'
            $result.InstalledState.Version | Should -Be '26.02'
            $result.InstalledState.VersionSource | Should -Be 'Registry'
            $result.Decision.IsUpdateAvailable | Should -BeTrue
            $result.Decision.SelectedRelease.Version | Should -Be '26.03'
            $result.Decision.SelectedRelease.ReleaseId | Should -Be 'release-26.03'
        }
    }

    It 'derives the current OS architecture when presentation callers omit it' {
        InModuleScope Wintainium.Core {
            Mock Get-WintainiumApplicationUpdateDecision {
                param(
                    [string]$ManifestPath,
                    [string]$StateRoot,
                    [string]$MachineArchitecture
                )

                [pscustomobject][ordered]@{
                    OperationId = 'operation-update-status-default-architecture'
                    IsSuccessful = $true
                    Status = 'NoUpdateAvailable'
                    Manifest = [pscustomobject]@{ Id = 'example.app'; Name = 'Example' }
                    InstalledState = [pscustomobject]@{ ApplicationId = 'example.app'; InstallationState = 'Installed'; Version = '26.03' }
                    Decision = [pscustomobject][ordered]@{
                        IsUpdateAvailable = $false
                        ReasonCode = 'Current'
                        Reason = 'Installed version is current.'
                        IsDeterministic = $true
                        SelectedRelease = $null
                    }
                    Errors = @()
                    Warnings = @()
                    LogEvents = @()
                }
            }

            $result = Get-WintainiumApplicationUpdateStatus -ManifestPath 'C:\manifest.json' -StateRoot 'C:\state'

            $expectedArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
            $result.IsSuccessful | Should -BeTrue
            Should -Invoke Get-WintainiumApplicationUpdateDecision -Times 1 -Exactly -ParameterFilter {
                $MachineArchitecture -eq $expectedArchitecture
            }
        }
    }

    It 'preserves reconciliation failure diagnostics without inventing update status' {
        InModuleScope Wintainium.Core {
            Mock Get-WintainiumApplicationUpdateDecision {
                [pscustomobject][ordered]@{
                    OperationId = 'operation-update-status-failed'
                    IsSuccessful = $false
                    Status = 'InstalledStateReconciliationUnsuccessful'
                    Manifest = [pscustomobject]@{ Id = 'example.app'; Name = 'Example' }
                    InstalledState = [pscustomobject][ordered]@{
                        ApplicationId = 'example.app'
                        InstallationState = 'Unknown'
                    }
                    Decision = $null
                    Errors = @([pscustomobject]@{
                        Code = 'WindowsReconciliationSettingsMissing'
                        Path = '$.reconciliation.settings'
                        Message = 'reconciliation settings are required.'
                    })
                    Warnings = @()
                    LogEvents = @()
                }
            }

            $result = Get-WintainiumApplicationUpdateStatus -ManifestPath 'C:\manifest.json' -StateRoot 'C:\state' -MachineArchitecture 'x64'

            $result.IsSuccessful | Should -BeFalse
            $result.Status | Should -Be 'InstalledStateReconciliationUnsuccessful'
            $result.InstalledState.InstallationState | Should -Be 'Unknown'
            $result.Decision | Should -BeNullOrEmpty
            $result.Errors[0].Code | Should -Be 'WindowsReconciliationSettingsMissing'
        }
    }
}
