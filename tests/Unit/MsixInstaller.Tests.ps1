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
        $result = InModuleScope Wintainium.Core {
            Test-WintainiumPluginDescriptor -DescriptorPath $using:descriptorPath
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

        $result.ExecutablePath | Should -Be (Get-Command powershell.exe).Source
        $result.Arguments[0..3] | Should -Be @('-NoProfile','-NonInteractive','-Command','Add-AppxPackage -Path $args[0]')
        $result.Arguments[4] | Should -Be ([System.IO.Path]::GetFullPath($script:artifactPath))
        $result.Arguments -join ' ' | Should -Not -Match '(?i)cmd\.exe|start-process|&\s+.*msix'
    }

    It 'accepts optional string-array Add-AppxPackage arguments' {
        $module = Import-Module $script:modulePath -Force -PassThru
        $invocation = [pscustomobject]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'MSIX'
            Settings = [pscustomobject]@{ arguments = @('-ForceApplicationShutdown') }
        }

        $result = & $module { param($value) Invoke-WintainiumInstaller -Invocation $value } $invocation

        $result.Arguments[3] | Should -Be 'Add-AppxPackage -Path $args[0] -ForceApplicationShutdown'
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

    It 'rejects scalar arguments' {
        $module = Import-Module $script:modulePath -Force -PassThru
        $invocation = [pscustomobject]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'msix'
            Settings = [pscustomobject]@{ arguments = '-ForceApplicationShutdown' }
        }

        { & $module { param($value) Invoke-WintainiumInstaller -Invocation $value } $invocation } |
            Should -Throw '*arguments must be an array of strings*'
    }

    It 'rejects non-string arguments' {
        $module = Import-Module $script:modulePath -Force -PassThru
        $invocation = [pscustomobject]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'msix'
            Settings = [pscustomobject]@{ arguments = @('-ForceApplicationShutdown', 7) }
        }

        { & $module { param($value) Invoke-WintainiumInstaller -Invocation $value } $invocation } |
            Should -Throw '*arguments must contain only strings*'
    }

    It 'rejects empty arguments' {
        $module = Import-Module $script:modulePath -Force -PassThru
        $invocation = [pscustomobject]@{
            ArtifactPath = $script:artifactPath
            ArtifactFormat = 'msix'
            Settings = [pscustomobject]@{ arguments = @('') }
        }

        { & $module { param($value) Invoke-WintainiumInstaller -Invocation $value } $invocation } |
            Should -Throw '*arguments must not contain empty strings*'
    }
}
