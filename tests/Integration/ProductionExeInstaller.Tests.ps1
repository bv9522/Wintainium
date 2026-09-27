BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:productionPluginRoot = Join-Path -Path $script:testRoot -ChildPath 'plugins'

    Import-Module $script:modulePath -Force
}

Describe 'Production EXE installer composition' {
    It 'flows from registry selection through invocation and controlled process execution' {
        $pwshPath = (Get-Command pwsh -CommandType Application).Source
        # Use the installed PowerShell apphost directly. Renaming a .NET apphost can
        # change the adjacent runtime/dll resolution behavior, so the test artifact
        # remains the real executable while still exercising the production EXE path.
        $artifactPath = [System.IO.Path]::GetFullPath($pwshPath)

        $registry = InModuleScope Wintainium.Core -Parameters @{ Path = $script:productionPluginRoot } {
            Get-WintainiumPluginRegistry -PluginRoot $Path
        }

        $installer = @($registry.Plugins | Where-Object {
            $_.PluginId -eq 'Wintainium.installer.exe' -and $_.PluginType -eq 'Installer'
        })
        $installer.Count | Should -Be 1

        $manifest = [pscustomobject][ordered]@{
            Installer = [pscustomobject][ordered]@{
                pluginId = 'Wintainium.installer.exe'
                requiredContractVersion = '1'
                settings = [pscustomobject][ordered]@{
                    arguments = @('-NoProfile', '-Command', "Write-Output 'production-exe-installer-ok'")
                }
            }
        }

        $artifact = [pscustomobject][ordered]@{
            format = 'exe'
            Uri = 'https://example.invalid/safe-fixture.exe'
        }

        $selection = InModuleScope Wintainium.Core -Parameters @{
            Manifest = $manifest
            Artifact = $artifact
            Plugins = $installer
        } {
            Select-WintainiumInstaller -Manifest $Manifest -Artifact $Artifact -Plugins $Plugins
        }

        $selection.IsSelected | Should -Be $true
        $selection.InstallerPlugin.PluginId | Should -Be 'Wintainium.installer.exe'
        $selection.ArtifactFormat | Should -Be 'exe'
        $selection.InstallationMode | Should -Be 'process'

        $downloadResult = [pscustomobject][ordered]@{
            OperationId = '11111111-1111-1111-1111-111111111111'
            Status = 'Downloaded'
            Uri = 'https://example.invalid/safe-fixture.exe'
            FileName = 'safe-fixture.exe'
            DestinationPath = $artifactPath
        }

        $requestResult = InModuleScope Wintainium.Core -Parameters @{
            DownloadResult = $downloadResult
            Manifest = $manifest
            OperationId = '22222222-2222-2222-2222-222222222222'
        } {
            New-WintainiumInstallerRequest -DownloadResult $DownloadResult -Manifest $Manifest -OperationId $OperationId
        }

        $requestResult.IsValid | Should -Be $true

        $invocationResult = InModuleScope Wintainium.Core -Parameters @{
            Selection = $selection
            Request = $requestResult.Request
        } {
            New-WintainiumInstallerInvocation -Selection $Selection -Request $Request
        }

        $invocationResult.IsValid | Should -Be $true
        $invocationResult.Invocation.PluginId | Should -Be 'Wintainium.installer.exe'
        $invocationResult.Invocation.InstallationMode | Should -Be 'process'
        $invocationResult.Invocation.ArtifactPath | Should -Be ([System.IO.Path]::GetFullPath($artifactPath))

        $installation = InModuleScope Wintainium.Core -Parameters @{
            Invocation = $invocationResult.Invocation
        } {
            Invoke-WintainiumInstallerOperation -Invocation $Invocation -TimeoutMilliseconds 10000
        }

        $installation.Status | Should -Be 'Completed'
        $installation.FailureKind | Should -Be $null
        $installation.PluginId | Should -Be 'Wintainium.installer.exe'
        $installation.OperationId | Should -Be '22222222-2222-2222-2222-222222222222'
        $installation.DownloadOperationId | Should -Be '11111111-1111-1111-1111-111111111111'
        $installation.ExitCode | Should -Be 0
        $installation.StandardOutput.Trim() | Should -Be 'production-exe-installer-ok'
        $installation.ErrorMessage | Should -Be $null
    }
}
