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
        $expectedPowerShell=[System.IO.Path]::GetFullPath((Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'))
        $result.ExecutablePath | Should -Be $expectedPowerShell
        @($result.Arguments) | Should -Contain '-EncodedCommand'
        $encodedCommand = $result.Arguments[-1]
        $decodedCommand = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encodedCommand))
        $decodedCommand | Should -Match ([regex]::Escape($script:artifactPath))
        $decodedCommand | Should -Match ([regex]::Escape($script:destination))
        $decodedCommand | Should -Match 'Expand-Archive -LiteralPath .* -DestinationPath .* -Force'
    }
    It 'extracts the archive using the returned encoded PowerShell command' {
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=$script:destination}}
        $spec=&$script:installerCommand -Invocation $inv
        $processResult = InModuleScope Wintainium.Core -Parameters @{ ExecutablePath=$spec.ExecutablePath; Arguments=$spec.Arguments } {
            Invoke-WintainiumInstallerProcess -FilePath $ExecutablePath -ArgumentList $Arguments -TimeoutMilliseconds 30000
        }

        $processResult.Status | Should -Be 'Completed' -Because $processResult.StandardError
        Test-Path -LiteralPath (Join-Path $script:destination 'payload.txt') -PathType Leaf | Should -BeTrue
        Get-Content -LiteralPath (Join-Path $script:destination 'payload.txt') -Raw | Should -Match 'portable test'
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
    It 'rejects an absolute entryPoint' {
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=$script:destination;entryPoint=(Join-Path $script:destination 'bin/app.exe')}}
        { &$script:installerCommand -Invocation $inv } | Should -Throw
    }
    It 'rejects parent-directory traversal in entryPoint' {
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=$script:destination;entryPoint='../outside/app.exe'}}
        { &$script:installerCommand -Invocation $inv } | Should -Throw
    }
    It 'rejects an empty entryPoint' {
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=$script:destination;entryPoint=''}}
        { &$script:installerCommand -Invocation $inv } | Should -Throw
    }
}
