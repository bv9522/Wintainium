BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'
    $script:installerPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.installer.portable-zip/Wintainium.installer.portable-zip.psm1'
    $script:descriptorPath = Join-Path -Path $script:testRoot -ChildPath 'plugins/Wintainium.installer.portable-zip/plugin.json'
    Import-Module $script:modulePath -Force
    $script:installerModule = Import-Module $script:installerPath -Force -PassThru
    $script:installerCommand = Get-Command -Module $script:installerModule.Name -Name Invoke-WintainiumInstaller
    $script:tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('Wintainium-PortableZip-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    $script:artifactPath = Join-Path $script:tempRoot 'app.zip'
    Set-Content (Join-Path $script:tempRoot 'payload.txt') 'portable test' -Encoding utf8
    Compress-Archive -Path (Join-Path $script:tempRoot 'payload.txt') -DestinationPath $script:artifactPath
    $script:destination = Join-Path $script:tempRoot 'installed'
}
AfterAll {
    Remove-Item $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Module $script:installerModule -Force -ErrorAction SilentlyContinue
}
Describe 'Wintainium generic portable ZIP installer' {
    It 'has a valid archive installer descriptor' {
        $result = InModuleScope Wintainium.Core -Parameters @{ Path=$script:descriptorPath } { Test-WintainiumPluginDescriptor -DescriptorPath $Path }
        $result.IsValid | Should -Be $true
        $result.Descriptor.pluginId | Should -Be 'Wintainium.installer.portable-zip'
        @($result.Descriptor.capabilities.supportedFormats) | Should -Be @('zip')
        $result.Descriptor.capabilities.installationMode | Should -Be 'archive'
    }
    It 'returns a process specification for archive extraction' {
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=$script:destination}}
        $result=&$script:installerCommand -Invocation $inv
        $result.ExecutablePath | Should -Not -BeNullOrEmpty
        @($result.Arguments) | Should -Contain $script:artifactPath
        @($result.Arguments) | Should -Contain $script:destination
    }
    It 'accepts an optional entryPoint setting' {
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=$script:destination;entryPoint='bin/app.exe'}}
        { &$script:installerCommand -Invocation $inv } | Should -Not -Throw
    }
    It 'rejects a non-ZIP artifact format' {
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='exe';Settings=[ordered]@{destinationPath=$script:destination}}
        { &$script:installerCommand -Invocation $inv } | Should -Throw
    }
    It 'rejects a relative destination path' {
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath='installed'}}
        { &$script:installerCommand -Invocation $inv } | Should -Throw
    }
    It 'rejects missing destinationPath' {
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{}}
        { &$script:installerCommand -Invocation $inv } | Should -Throw
    }
    It 'rejects an empty entryPoint' {
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=$script:destination;entryPoint=''}}
        { &$script:installerCommand -Invocation $inv } | Should -Throw
    }
}
