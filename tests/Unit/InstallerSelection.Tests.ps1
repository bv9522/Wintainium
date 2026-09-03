BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

    Import-Module $script:modulePath -Force

    $script:manifest = [ordered]@{
        installer = [ordered]@{
            pluginId = 'Wintainium.installer.exe'
            requiredContractVersion = '1'
            settings = [ordered]@{}
        }
        artifact = [ordered]@{
            formats = @('exe')
            architectures = @('x64')
        }
    }

    $script:exePlugin = [pscustomobject]@{
        PluginId = 'Wintainium.installer.exe'
        PluginType = 'Installer'
        ContractVersions = @('1')
        Capabilities = [ordered]@{ supportedFormats = @('exe') }
        DescriptorPath = 'C:\plugins\exe\plugin.json'
    }

    $script:zipPlugin = [pscustomobject]@{
        PluginId = 'Wintainium.installer.portable-zip'
        PluginType = 'Installer'
        ContractVersions = @('1')
        Capabilities = [ordered]@{ supportedFormats = @('zip') }
        DescriptorPath = 'C:\plugins\zip\plugin.json'
    }
}

Describe 'Wintainium installer selection' {
    It 'selects the manifest-declared installer when the artifact format is supported' {
        $artifact = [ordered]@{ format = 'exe' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Manifest = $script:manifest; Artifact = $artifact; Plugins = @($script:exePlugin, $script:zipPlugin) } {
            Select-WintainiumInstaller -Manifest $Manifest -Artifact $Artifact -Plugins $Plugins
        }

        $result.IsSelected | Should -Be $true
        $result.InstallerPlugin.PluginId | Should -Be 'Wintainium.installer.exe'
        $result.ArtifactFormat | Should -Be 'exe'
        $result.Error | Should -Be $null
    }

    It 'matches artifact formats case-insensitively' {
        $artifact = [ordered]@{ format = 'EXE' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Manifest = $script:manifest; Artifact = $artifact; Plugins = @($script:exePlugin) } {
            Select-WintainiumInstaller -Manifest $Manifest -Artifact $Artifact -Plugins $Plugins
        }

        $result.IsSelected | Should -Be $true
    }

    It 'rejects an artifact whose format is unsupported by the selected installer' {
        $artifact = [ordered]@{ format = 'msi' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Manifest = $script:manifest; Artifact = $artifact; Plugins = @($script:exePlugin) } {
            Select-WintainiumInstaller -Manifest $Manifest -Artifact $Artifact -Plugins $Plugins
        }

        $result.IsSelected | Should -Be $false
        $result.Error.Code | Should -Be 'InstallerSelectionArtifactIncompatible'
    }

    It 'rejects an artifact without an explicit format instead of guessing from its filename' {
        $artifact = [ordered]@{ fileName = 'setup.exe' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Manifest = $script:manifest; Artifact = $artifact; Plugins = @($script:exePlugin) } {
            Select-WintainiumInstaller -Manifest $Manifest -Artifact $Artifact -Plugins $Plugins
        }

        $result.IsSelected | Should -Be $false
        $result.Error.Code | Should -Be 'InstallerSelectionArtifactFormatMissing'
    }

    It 'returns the plugin resolution error when the required installer is not registered' {
        $artifact = [ordered]@{ format = 'exe' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Manifest = $script:manifest; Artifact = $artifact; Plugins = @($script:zipPlugin) } {
            Select-WintainiumInstaller -Manifest $Manifest -Artifact $Artifact -Plugins $Plugins
        }

        $result.IsSelected | Should -Be $false
        $result.Error.Code | Should -Be 'PluginNotResolved'
    }

    It 'requires the manifest installer contract version to be registered' {
        $manifest = [ordered]@{
            installer = [ordered]@{
                pluginId = 'Wintainium.installer.exe'
                requiredContractVersion = '2'
                settings = [ordered]@{}
            }
            artifact = [ordered]@{
                formats = @('exe')
                architectures = @('x64')
            }
        }
        $artifact = [ordered]@{ format = 'exe' }
        $result = InModuleScope Wintainium.Core -Parameters @{ Manifest = $manifest; Artifact = $artifact; Plugins = @($script:exePlugin) } {
            Select-WintainiumInstaller -Manifest $Manifest -Artifact $Artifact -Plugins $Plugins
        }

        $result.IsSelected | Should -Be $false
        $result.Error.Code | Should -Be 'PluginNotResolved'
    }
}
