BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:installerPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.installer.msi/Wintainium.installer.msi.psm1'
    $script:descriptorPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.installer.msi/plugin.json'

    Import-Module $script:modulePath -Force
    $script:installerModule = Import-Module $script:installerPath -Force -PassThru
    $script:installerCommand = Get-Command -Module $script:installerModule.Name -Name 'Invoke-WintainiumInstaller' -CommandType Function

    $script:tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('Wintainium-MsiInstaller-' + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    $script:artifactPath = Join-Path -Path $script:tempRoot 'setup.msi'
    Set-Content -LiteralPath $script:artifactPath -Value 'test MSI' -Encoding utf8

    $script:invocation = [pscustomobject][ordered]@{
        ArtifactPath = $script:artifactPath
        ArtifactFormat = 'msi'
        Settings = [ordered]@{
            arguments = @('/qn', '/norestart')
        }
    }
}

AfterAll {
    Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Module $script:installerModule -Force -ErrorAction SilentlyContinue
}

Describe 'Wintainium generic MSI installer' {
    It 'has a valid installer descriptor' {
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $script:descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $true
        $result.Descriptor.pluginId | Should -Be 'Wintainium.installer.msi'
        $result.Descriptor.pluginType | Should -Be 'Installer'
        @($result.Descriptor.capabilities.supportedFormats) | Should -Be @('msi')
        $result.Descriptor.capabilities.installationMode | Should -Be 'process'
    }

    It 'targets the Windows Installer executable and downloaded MSI artifact' {
        $result = & $script:installerCommand -Invocation $script:invocation

        $expectedMsiexec = [System.IO.Path]::GetFullPath((Join-Path $env:WINDIR 'System32/msiexec.exe'))
        $result.ExecutablePath | Should -Be $expectedMsiexec
        @($result.Arguments) | Should -Be @('/i', [System.IO.Path]::GetFullPath($script:artifactPath), '/qn', '/norestart')
    }

    It 'defaults to the required MSI install arguments when optional arguments are omitted' {
        $invocation = [pscustomobject][ordered]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'msi'
            Settings = [ordered]@{}
        }

        $result = & $script:installerCommand -Invocation $invocation

        @($result.Arguments) | Should -Be @('/i', [System.IO.Path]::GetFullPath($script:artifactPath))
    }

    It 'rejects a non-MSI artifact format' {
        $invocation = [pscustomobject][ordered]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'exe'
            Settings = [ordered]@{}
        }

        { & $script:installerCommand -Invocation $invocation } | Should -Throw
    }

    It 'rejects a scalar arguments setting' {
        $invocation = [pscustomobject][ordered]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'msi'
            Settings = [ordered]@{ arguments = '/qn' }
        }

        { & $script:installerCommand -Invocation $invocation } | Should -Throw
    }

    It 'rejects non-string arguments' {
        $invocation = [pscustomobject][ordered]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'msi'
            Settings = [ordered]@{ arguments = @('/qn', 7) }
        }

        { & $script:installerCommand -Invocation $invocation } | Should -Throw
    }

    It 'does not construct a shell command' {
        $result = & $script:installerCommand -Invocation $script:invocation

        $result.PSObject.Properties.Name | Should -Contain 'ExecutablePath'
        $result.PSObject.Properties.Name | Should -Contain 'Arguments'
        $result.PSObject.Properties.Name | Should -Not -Contain 'Command'
        $result.PSObject.Properties.Name | Should -Not -Contain 'CommandLine'
    }
}
