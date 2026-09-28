BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force
}

Describe 'Wintainium installer compatibility' {
    It 'matches manifest formats case-insensitively' {
        $manifest = [pscustomobject]@{
            artifact = [pscustomobject]@{ formats = @('MSIX') }
        }
        $plugin = [pscustomobject]@{
            PluginId = 'Wintainium.installer.msix'
            Capabilities = [ordered]@{ supportedFormats = @('msix') }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Manifest = $manifest; Plugin = $plugin } {
            Test-WintainiumInstallerCompatibility -Manifest $Manifest -InstallerPlugin $Plugin
        }

        $result.IsCompatible | Should -Be $true
        $result.Error | Should -BeNullOrEmpty
    }

    It 'rejects a manifest when none of its formats are supported' {
        $manifest = [pscustomobject]@{
            artifact = [pscustomobject]@{ formats = @('msix','exe') }
        }
        $plugin = [pscustomobject]@{
            PluginId = 'Wintainium.installer.msi'
            Capabilities = [ordered]@{ supportedFormats = @('msi') }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Manifest = $manifest; Plugin = $plugin } {
            Test-WintainiumInstallerCompatibility -Manifest $Manifest -InstallerPlugin $Plugin
        }

        $result.IsCompatible | Should -Be $false
        $result.Error.Code | Should -Be 'InstallerArtifactIncompatible'
    }

    It 'uses the manifest format order when a plugin supports multiple formats' {
        $manifest = [pscustomobject]@{
            artifact = [pscustomobject]@{ formats = @('msi','exe') }
        }
        $plugin = [pscustomobject]@{
            PluginId = 'Wintainium.installer.multi'
            Capabilities = [ordered]@{ supportedFormats = @('exe','msi') }
        }

        $result = InModuleScope Wintainium.Core -Parameters @{ Manifest = $manifest; Plugin = $plugin } {
            Test-WintainiumInstallerCompatibility -Manifest $Manifest -InstallerPlugin $Plugin
        }

        $result.IsCompatible | Should -Be $true
    }
}
