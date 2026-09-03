BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

    Import-Module $script:modulePath -Force

    $script:tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('Wintainium-InstallerInvocation-' + [guid]::NewGuid().ToString())
    $script:pluginRoot = Join-Path -Path $script:tempRoot -ChildPath 'installer'
    New-Item -ItemType Directory -Path $script:pluginRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $script:pluginRoot 'Installer.psm1') -Value '# test fixture' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $script:pluginRoot 'artifact.exe') -Value 'test artifact' -Encoding utf8

    $script:descriptorPath = Join-Path $script:pluginRoot 'plugin.json'
    Set-Content -LiteralPath $script:descriptorPath -Value '{}' -Encoding utf8

    $script:plugin = [pscustomobject]@{
        PluginId = 'Wintainium.installer.exe'
        PluginType = 'Installer'
        ContractVersions = @('1')
        EntryPoint = 'Installer.psm1'
        Capabilities = [ordered]@{ supportedFormats = @('exe') }
        DescriptorPath = $script:descriptorPath
    }

    $script:selection = [pscustomobject][ordered]@{
        IsSelected = $true
        InstallerPlugin = $script:plugin
        ArtifactFormat = 'exe'
        Error = $null
    }

    $script:request = [pscustomobject][ordered]@{
        OperationId = 'installer-operation'
        DownloadOperationId = 'download-operation'
        Installer = [pscustomobject][ordered]@{
            pluginId = 'Wintainium.installer.exe'
            requiredContractVersion = '1'
            settings = [ordered]@{ silent = $true }
        }
        Artifact = [pscustomobject][ordered]@{
            Uri = 'https://example.invalid/artifact.exe'
            FileName = 'artifact.exe'
            Path = (Join-Path $script:pluginRoot 'artifact.exe')
        }
    }
}

AfterAll {
    Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Wintainium installer invocation preparation' {
    It 'prepares a constrained invocation from a successful selection and installer request' {
        $result = InModuleScope Wintainium.Core -Parameters @{ Selection = $script:selection; Request = $script:request } {
            New-WintainiumInstallerInvocation -Selection $Selection -Request $Request
        }

        $result.IsValid | Should -Be $true
        $result.Invocation.PluginId | Should -Be 'Wintainium.installer.exe'
        $result.Invocation.PluginModulePath | Should -Be (Join-Path $script:pluginRoot 'Installer.psm1')
        $result.Invocation.ArtifactPath | Should -Be (Join-Path $script:pluginRoot 'artifact.exe')
        $result.Invocation.Settings.silent | Should -Be $true
        $result.Error | Should -Be $null
    }

    It 'rejects an unsuccessful installer selection' {
        $selection = [pscustomobject][ordered]@{ IsSelected = $false; InstallerPlugin = $null; ArtifactFormat = 'exe'; Error = $null }
        $result = InModuleScope Wintainium.Core -Parameters @{ Selection = $selection; Request = $script:request } {
            New-WintainiumInstallerInvocation -Selection $Selection -Request $Request
        }

        $result.IsValid | Should -Be $false
        $result.Error.Code | Should -Be 'InstallerInvocationSelectionInvalid'
    }

    It 'requires the selected installer plugin' {
        $selection = [pscustomobject][ordered]@{ IsSelected = $true; InstallerPlugin = $null; ArtifactFormat = 'exe'; Error = $null }
        $result = InModuleScope Wintainium.Core -Parameters @{ Selection = $selection; Request = $script:request } {
            New-WintainiumInstallerInvocation -Selection $Selection -Request $Request
        }

        $result.Error.Code | Should -Be 'InstallerInvocationPluginMissing'
    }

    It 'rejects an installer plugin without an entry point' {
        $plugin = [pscustomobject]@{ PluginId = 'Wintainium.installer.exe'; DescriptorPath = $script:descriptorPath }
        $selection = [pscustomobject][ordered]@{ IsSelected = $true; InstallerPlugin = $plugin; ArtifactFormat = 'exe'; Error = $null }
        $result = InModuleScope Wintainium.Core -Parameters @{ Selection = $selection; Request = $script:request } {
            New-WintainiumInstallerInvocation -Selection $Selection -Request $Request
        }

        $result.Error.Code | Should -Be 'InstallerInvocationEntryPointMissing'
    }

    It 'rejects absolute or traversal entry points' {
        foreach ($entryPoint in @((Join-Path $script:pluginRoot 'Installer.psm1'), '..\Installer.psm1')) {
            $plugin = [pscustomobject]@{ PluginId = 'Wintainium.installer.exe'; EntryPoint = $entryPoint; DescriptorPath = $script:descriptorPath }
            $selection = [pscustomobject][ordered]@{ IsSelected = $true; InstallerPlugin = $plugin; ArtifactFormat = 'exe'; Error = $null }
            $result = InModuleScope Wintainium.Core -Parameters @{ Selection = $selection; Request = $script:request } {
                New-WintainiumInstallerInvocation -Selection $Selection -Request $Request
            }

            $result.Error.Code | Should -Be 'InstallerInvocationEntryPointInvalid'
        }
    }

    It 'rejects an entry point outside the plugin root' {
        $outsidePath = Join-Path $script:tempRoot 'outside.psm1'
        Set-Content -LiteralPath $outsidePath -Value '# outside' -Encoding utf8
        $plugin = [pscustomobject]@{ PluginId = 'Wintainium.installer.exe'; EntryPoint = 'nested/../outside.psm1'; DescriptorPath = $script:descriptorPath }
        $selection = [pscustomobject][ordered]@{ IsSelected = $true; InstallerPlugin = $plugin; ArtifactFormat = 'exe'; Error = $null }
        $result = InModuleScope Wintainium.Core -Parameters @{ Selection = $selection; Request = $script:request } {
            New-WintainiumInstallerInvocation -Selection $Selection -Request $Request
        }

        $result.Error.Code | Should -Be 'InstallerInvocationEntryPointInvalid'
    }

    It 'rejects a missing entry point file' {
        $plugin = [pscustomobject]@{ PluginId = 'Wintainium.installer.exe'; EntryPoint = 'Missing.psm1'; DescriptorPath = $script:descriptorPath }
        $selection = [pscustomobject][ordered]@{ IsSelected = $true; InstallerPlugin = $plugin; ArtifactFormat = 'exe'; Error = $null }
        $result = InModuleScope Wintainium.Core -Parameters @{ Selection = $selection; Request = $script:request } {
            New-WintainiumInstallerInvocation -Selection $Selection -Request $Request
        }

        $result.Error.Code | Should -Be 'InstallerInvocationEntryPointMissingFile'
    }

    It 'rejects a missing or invalid artifact path' {
        $request = [pscustomobject][ordered]@{
            OperationId = 'installer-operation'
            DownloadOperationId = 'download-operation'
            Installer = $script:request.Installer
            Artifact = [pscustomobject][ordered]@{ Path = 'artifact.exe' }
        }
        $result = InModuleScope Wintainium.Core -Parameters @{ Selection = $script:selection; Request = $request } {
            New-WintainiumInstallerInvocation -Selection $Selection -Request $Request
        }

        $result.Error.Code | Should -Be 'InstallerInvocationArtifactPathInvalid'
    }
}
