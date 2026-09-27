BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:installerPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.installer.exe/Wintainium.installer.exe.psm1'
    $script:descriptorPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.installer.exe/plugin.json'

    Import-Module $script:modulePath -Force
    $script:installerModule = Import-Module $script:installerPath -Force -PassThru
    $script:installerCommand = Get-Command -Module $script:installerModule.Name -Name 'Invoke-WintainiumInstaller' -CommandType Function

    $script:tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('Wintainium-ExeInstaller-' + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    $script:artifactPath = Join-Path -Path $script:tempRoot 'setup.exe'
    Set-Content -LiteralPath $script:artifactPath -Value 'test executable' -Encoding utf8

    $script:invocation = [pscustomobject][ordered]@{
        ArtifactPath = $script:artifactPath
        ArtifactFormat = 'exe'
        Settings = [ordered]@{
            arguments = @('/S', '/D=C:Program FilesTest')
        }
    }
}

AfterAll {
    Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Module $script:installerModule -Force -ErrorAction SilentlyContinue
}

Describe 'Wintainium generic EXE installer' {
    It 'has a valid installer descriptor' {
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $script:descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }

        $result.IsValid | Should -Be $true
        $result.Descriptor.pluginId | Should -Be 'Wintainium.installer.exe'
        $result.Descriptor.pluginType | Should -Be 'Installer'
        @($result.Descriptor.capabilities.supportedFormats) | Should -Be @('exe')
        $result.Descriptor.capabilities.installationMode | Should -Be 'process'
    }

    It 'uses the downloaded artifact as the executable path' {
        $result = & $script:installerCommand -Invocation $script:invocation

        $result.ExecutablePath | Should -Be ([System.IO.Path]::GetFullPath($script:artifactPath))
        @($result.Arguments) | Should -Be @('/S', '/D=C:Program FilesTest')
    }

    It 'defaults to no arguments when arguments are omitted' {
        $invocation = [pscustomobject][ordered]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'exe'
            Settings = [ordered]@{}
        }

        $result = & $script:installerCommand -Invocation $invocation

        @($result.Arguments).Count | Should -Be 0
    }

    It 'rejects a non-EXE artifact format' {
        $invocation = [pscustomobject][ordered]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'msi'
            Settings = [ordered]@{}
        }

        { & $script:installerModule -Invocation $invocation } | Should -Throw
    }

    It 'rejects a scalar arguments setting' {
        $invocation = [pscustomobject][ordered]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'exe'
            Settings = [ordered]@{ arguments = '/S' }
        }

        { & $script:installerModule -Invocation $invocation } | Should -Throw
    }

    It 'rejects non-string arguments' {
        $invocation = [pscustomobject][ordered]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'exe'
            Settings = [ordered]@{ arguments = @('/S', 7) }
        }

        { & $script:installerModule -Invocation $invocation } | Should -Throw
    }

    It 'does not construct a shell command' {
        $result = & $script:installerModule -Invocation $script:invocation

        $result.PSObject.Properties.Name | Should -Contain 'ExecutablePath'
        $result.PSObject.Properties.Name | Should -Contain 'Arguments'
        $result.PSObject.Properties.Name | Should -Not -Contain 'Command'
        $result.PSObject.Properties.Name | Should -Not -Contain 'CommandLine'
    }
}
