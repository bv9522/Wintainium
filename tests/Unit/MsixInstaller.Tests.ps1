BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:pluginRoot = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.installer.msix'
    $script:descriptorPath = Join-Path -Path $script:pluginRoot -ChildPath 'plugin.json'
    $script:modulePath = Join-Path -Path $script:pluginRoot -ChildPath 'Wintainium.installer.msix.psm1'
    $script:artifactPath = Join-Path -Path $TestDrive -ChildPath 'test.msix'
    Set-Content -LiteralPath $script:artifactPath -Value 'not-a-real-msix-package' -Encoding utf8
    $script:descriptor = Get-Content -LiteralPath $script:descriptorPath -Raw | ConvertFrom-Json
}

Describe 'Wintainium MSIX installer plugin' {
    It 'has a valid package installer descriptor' {
        $result = InModuleScope Wintainium.Core -Parameters @{ Path = $script:descriptorPath } {
            Test-WintainiumPluginDescriptor -DescriptorPath $Path
        }
        $result.IsValid | Should -Be $true
        $result.Descriptor.pluginId | Should -Be 'Wintainium.installer.msix'
        $result.Descriptor.capabilities.supportedFormats | Should -Be @('msix')
        $result.Descriptor.capabilities.installationMode | Should -Be 'package'
    }

    It 'targets Add-AppxPackage with the absolute MSIX artifact' {
        $module = Import-Module $script:modulePath -Force -PassThru
        $invocation = [pscustomobject]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'msix'
            Settings = [pscustomobject]@{}
        }

        $result = & $module { param($value) Invoke-WintainiumInstaller -Invocation $value } $invocation

        $result.ExecutablePath | Should -Be (Get-Command powershell.exe).Path
        $result.Arguments[0..3] | Should -Be @('-NoProfile','-NonInteractive','-Command','$settings = $args[1] | ConvertFrom-Json -AsHashtable; Add-AppxPackage -Path $args[0] @settings')
        $result.Arguments[4] | Should -Be ([System.IO.Path]::GetFullPath($script:artifactPath))
        $result.Arguments[5] | Should -Be '{}'
        $result.Arguments -join ' ' | Should -Not -Match '(?i)cmd\.exe|start-process|invoke-expression'
    }

    It 'serializes structured Add-AppxPackage settings without constructing a shell command' {
        $module = Import-Module $script:modulePath -Force -PassThru
        $invocation = [pscustomobject]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'MSIX'
            Settings = [pscustomobject]@{ ForceApplicationShutdown = $true }
        }

        $result = & $module { param($value) Invoke-WintainiumInstaller -Invocation $value } $invocation

        $result.Arguments[5] | Should -Match '"ForceApplicationShutdown":true'
        $result.Arguments[3] | Should -Not -Match '(?i)ForceApplicationShutdown'
    }

    It 'rejects non-MSIX artifacts' {
        $module = Import-Module $script:modulePath -Force -PassThru
        $invocation = [pscustomobject]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'zip'
            Settings = [pscustomobject]@{}
        }

        { & $module { param($value) Invoke-WintainiumInstaller -Invocation $value } $invocation } |
            Should -Throw "*artifact format 'msix'*"
    }
}
