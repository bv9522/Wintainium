BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force
}

Describe 'Wintainium default application installer policy' {
    BeforeEach {
        $script:reconciler = [pscustomobject]@{
            PluginId = 'Wintainium.reconciliation.test'
            PluginType = 'Reconciliation'
            ContractVersions = @('1')
            Capabilities = [ordered]@{ applicationState = $true }
            DescriptorPath = 'reconciliation/plugin.json'
        }
    }

    It 'prefers EXE as the default mechanism when all production mechanisms are available' {
        $plugins = @(
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.zip'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('zip') }
                DescriptorPath = 'z/plugin.json'
            }
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.msi'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('msi') }
                DescriptorPath = 'm/plugin.json'
            }
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.msix'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('msix') }
                DescriptorPath = 'p/plugin.json'
            }
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.exe'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('exe') }
                DescriptorPath = 'e/plugin.json'
            }
            $script:reconciler
        )

        $result = InModuleScope Wintainium.Core -Parameters @{ Registry = [pscustomobject]@{ Plugins = $plugins } } {
            Get-WintainiumDefaultApplicationPolicy -PluginRegistry $Registry
        }

        $result.IsSuccessful | Should -Be $true
        $result.Policy.Installer.PluginId | Should -Be 'Wintainium.installer.exe'
        @($result.Policy.Artifact.Formats) | Should -Be @('exe')
    }

    It 'falls back from EXE to MSI when no EXE installer is registered' {
        $plugins = @(
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.zip'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('zip') }
                DescriptorPath = 'z/plugin.json'
            }
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.msix'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('msix') }
                DescriptorPath = 'p/plugin.json'
            }
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.msi'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('msi') }
                DescriptorPath = 'm/plugin.json'
            }
            $script:reconciler
        )

        $result = InModuleScope Wintainium.Core -Parameters @{ Registry = [pscustomobject]@{ Plugins = $plugins } } {
            Get-WintainiumDefaultApplicationPolicy -PluginRegistry $Registry
        }

        $result.IsSuccessful | Should -Be $true
        $result.Policy.Installer.PluginId | Should -Be 'Wintainium.installer.msi'
        @($result.Policy.Artifact.Formats) | Should -Be @('msi')
    }

    It 'falls back to MSIX before portable ZIP' {
        $plugins = @(
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.zip'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('zip') }
                DescriptorPath = 'z/plugin.json'
            }
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.msix'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('msix') }
                DescriptorPath = 'p/plugin.json'
            }
            $script:reconciler
        )

        $result = InModuleScope Wintainium.Core -Parameters @{ Registry = [pscustomobject]@{ Plugins = $plugins } } {
            Get-WintainiumDefaultApplicationPolicy -PluginRegistry $Registry
        }

        $result.IsSuccessful | Should -Be $true
        $result.Policy.Installer.PluginId | Should -Be 'Wintainium.installer.msix'
        @($result.Policy.Artifact.Formats) | Should -Be @('msix')
    }

    It 'uses portable ZIP when it is the only supported default mechanism' {
        $plugins = @(
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.zip'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('zip') }
                DescriptorPath = 'z/plugin.json'
            }
            $script:reconciler
        )

        $result = InModuleScope Wintainium.Core -Parameters @{ Registry = [pscustomobject]@{ Plugins = $plugins } } {
            Get-WintainiumDefaultApplicationPolicy -PluginRegistry $Registry
        }

        $result.IsSuccessful | Should -Be $true
        $result.Policy.Installer.PluginId | Should -Be 'Wintainium.installer.zip'
        @($result.Policy.Artifact.Formats) | Should -Be @('zip')
    }

    It 'matches supported formats case-insensitively' {
        $plugins = @(
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.exe'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('EXE') }
                DescriptorPath = 'e/plugin.json'
            }
            $script:reconciler
        )

        $result = InModuleScope Wintainium.Core -Parameters @{ Registry = [pscustomobject]@{ Plugins = $plugins } } {
            Get-WintainiumDefaultApplicationPolicy -PluginRegistry $Registry
        }

        $result.IsSuccessful | Should -Be $true
        $result.Policy.Installer.PluginId | Should -Be 'Wintainium.installer.exe'
        @($result.Policy.Artifact.Formats) | Should -Be @('exe')
    }

    It 'does not silently choose between two plugins supporting the same preferred format' {
        $plugins = @(
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.exe-a'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('exe') }
                DescriptorPath = 'a/plugin.json'
            }
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.exe-b'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('exe') }
                DescriptorPath = 'b/plugin.json'
            }
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.msi'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('msi') }
                DescriptorPath = 'm/plugin.json'
            }
            $script:reconciler
        )

        $result = InModuleScope Wintainium.Core -Parameters @{ Registry = [pscustomobject]@{ Plugins = $plugins } } {
            Get-WintainiumDefaultApplicationPolicy -PluginRegistry $Registry
        }

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'ApplicationPolicyAmbiguous'
        $result.Policy | Should -BeNullOrEmpty
        $result.Errors[0].Code | Should -Be 'ApplicationPolicyAmbiguous'
    }

    It 'ignores installer plugins that advertise no supported default format' {
        $plugins = @(
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.future'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('future-format') }
                DescriptorPath = 'f/plugin.json'
            }
            $script:reconciler
        )

        $registry = [pscustomobject]@{ Plugins = $plugins }
        $result = InModuleScope Wintainium.Core -Parameters @{ Registry = $registry } {
            Get-WintainiumDefaultApplicationPolicy -PluginRegistry $Registry
        }

        $result.IsSuccessful | Should -Be $false
        $result.Status | Should -Be 'ApplicationPolicyUnavailable'
        $result.Errors[0].Code | Should -Be 'ApplicationPolicyUnavailable'
    }

    It 'derives explicit Windows reconciliation settings from the normalized application name when required' {
        $reconcilingPlugin = [pscustomobject]@{
            PluginId = 'Wintainium.reconciliation.windows-installed-application'
            PluginType = 'Reconciliation'
            ContractVersions = @('1')
            Capabilities = [ordered]@{ applicationState = $true; requiresConfiguration = $true }
            DescriptorPath = 'reconciliation/windows/plugin.json'
        }
        $installer = [pscustomobject]@{
            PluginId = 'Wintainium.installer.exe'
            PluginType = 'Installer'
            ContractVersions = @('1')
            Capabilities = [ordered]@{ supportedFormats = @('exe') }
            DescriptorPath = 'installer/exe/plugin.json'
        }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Registry = [pscustomobject]@{ Plugins = @($installer, $reconcilingPlugin) }
            ApplicationName = 'Audacity'
        } {
            Get-WintainiumDefaultApplicationPolicy -PluginRegistry $Registry -ApplicationName $ApplicationName
        }

        $result.IsSuccessful | Should -Be $true
        $result.Policy.Reconciliation.PluginId | Should -Be 'Wintainium.reconciliation.windows-installed-application'
        @($result.Policy.Reconciliation.Settings.registry.locations).Count | Should -Be 3
        $result.Policy.Reconciliation.Settings.registry.matchMode | Should -Be 'any'
        @($result.Policy.Reconciliation.Settings.registry.match).Count | Should -Be 2
        $result.Policy.Reconciliation.Settings.registry.match[0].value | Should -Be 'DisplayName'
        $result.Policy.Reconciliation.Settings.registry.match[0].equals | Should -Be 'Audacity'
        $result.Policy.Reconciliation.Settings.registry.match[1].value | Should -Be 'subkey'
        $result.Policy.Reconciliation.Settings.registry.match[1].equals | Should -Be 'Audacity'
    }

    It 'retains architecture as a separate policy dimension from installer format' {
        $plugins = @(
            [pscustomobject]@{
                PluginId = 'Wintainium.installer.exe'
                PluginType = 'Installer'
                ContractVersions = @('1')
                Capabilities = [ordered]@{ supportedFormats = @('exe') }
                DescriptorPath = 'e/plugin.json'
            }
            $script:reconciler
        )

        $result = InModuleScope Wintainium.Core -Parameters @{ Registry = [pscustomobject]@{ Plugins = $plugins } } {
            Get-WintainiumDefaultApplicationPolicy -PluginRegistry $Registry
        }

        @($result.Policy.Artifact.Architectures) | Should -Be @('x64','x86','arm64','neutral')
        $result.Policy.Artifact.AllowUnknownArchitecture | Should -Be $false
    }
}
