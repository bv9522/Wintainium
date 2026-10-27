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
        $decodedCommand | Should -Match '\$ErrorActionPreference = ''Stop'''
        $decodedCommand | Should -Match '\[System\.IO\.Compression\.ZipFile\]::OpenRead'
        $decodedCommand | Should -Match '\[System\.IO\.FileMode\]::Create'
        $decodedCommand | Should -Match 'ZIP entry attempts to write outside destination'
        $decodedCommand | Should -Not -Match 'Expand-Archive'
        $decodedCommand | Should -Match 'catch'
        $decodedCommand | Should -Match 'exit 1'
    }
    It 'requests and tracks elevation for protected installation destinations' {
        $protectedDestination = Join-Path $env:ProgramFiles 'Wintanium-PortableZip-Elevation-Test'
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=$protectedDestination}}
        $spec=&$script:installerCommand -Invocation $inv
        $encodedCommand = $spec.Arguments[-1]
        $decodedCommand = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encodedCommand))

        $decodedCommand | Should -Match 'Start-Process'
        $decodedCommand | Should -Match '-Verb RunAs'
        $decodedCommand | Should -Match '-Wait'
        $decodedCommand | Should -Match '-PassThru'
        $decodedCommand | Should -Match '-RedirectStandardOutput'
        $decodedCommand | Should -Match '-RedirectStandardError'
        $decodedCommand | Should -Match 'ExitCode'
        $decodedCommand | Should -Match 'ElevationDenied'
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
    It 'overwrites an existing portable application file when extraction succeeds' {
        $overwriteDestination = Join-Path $script:tempRoot 'overwrite-destination'
        New-Item -ItemType Directory -Path $overwriteDestination -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $overwriteDestination 'payload.txt') -Value 'old version' -Encoding utf8
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=$overwriteDestination}}
        $spec=&$script:installerCommand -Invocation $inv
        $processResult = InModuleScope Wintainium.Core -Parameters @{ ExecutablePath=$spec.ExecutablePath; Arguments=$spec.Arguments } {
            Invoke-WintainiumInstallerProcess -FilePath $ExecutablePath -ArgumentList $Arguments -TimeoutMilliseconds 30000
        }

        $processResult.Status | Should -Be 'Completed' -Because $processResult.StandardError
        Get-Content -LiteralPath (Join-Path $overwriteDestination 'payload.txt') -Raw | Should -Match 'portable test'
        Get-Content -LiteralPath (Join-Path $overwriteDestination 'payload.txt') -Raw | Should -Not -Match 'old version'
    }

    It 'returns a failed process result when archive extraction fails' {
        $invalidArtifactPath = Join-Path $script:tempRoot 'invalid.zip'
        Set-Content -LiteralPath $invalidArtifactPath -Value 'not a zip archive' -Encoding utf8
        $inv=[pscustomobject]@{ArtifactPath=$invalidArtifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=(Join-Path $script:tempRoot 'invalid-destination')}}
        $spec=&$script:installerCommand -Invocation $inv
        $processResult = InModuleScope Wintainium.Core -Parameters @{ ExecutablePath=$spec.ExecutablePath; Arguments=$spec.Arguments } {
            Invoke-WintainiumInstallerProcess -FilePath $ExecutablePath -ArgumentList $Arguments -TimeoutMilliseconds 30000
        }

        $processResult.Status | Should -Be 'Failed'
        $processResult.ExitCode | Should -Not -Be 0
        $processResult.StandardError | Should -Not -BeNullOrEmpty
    }
    It 'rejects ZIP entries that attempt to escape the destination directory' {
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $traversalArtifactPath = Join-Path $script:tempRoot 'traversal.zip'
        $traversalSourceDirectory = Join-Path $script:tempRoot 'traversal-source'
        New-Item -ItemType Directory -Path $traversalSourceDirectory -Force | Out-Null
        $traversalPayload = Join-Path $traversalSourceDirectory 'payload.txt'
        Set-Content -LiteralPath $traversalPayload -Value 'must not escape' -Encoding utf8
        $archive = [System.IO.Compression.ZipFile]::Open($traversalArtifactPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try { [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $traversalPayload, '../outside-payload.txt') | Out-Null } finally { $archive.Dispose() }
        $traversalDestination = Join-Path $script:tempRoot 'traversal-destination'
        $inv=[pscustomobject]@{ArtifactPath=$traversalArtifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=$traversalDestination}}
        $spec=&$script:installerCommand -Invocation $inv
        $processResult = InModuleScope Wintainium.Core -Parameters @{ ExecutablePath=$spec.ExecutablePath; Arguments=$spec.Arguments } {
            Invoke-WintainiumInstallerProcess -FilePath $ExecutablePath -ArgumentList $Arguments -TimeoutMilliseconds 30000
        }

        $processResult.Status | Should -Be 'Failed'
        $processResult.StandardError | Should -Match 'ZIP entry attempts to write outside destination'
        Test-Path -LiteralPath (Join-Path $script:tempRoot 'outside-payload.txt') | Should -BeFalse
    }

    It 'fails when a configured entry point was not extracted' {
        $missingEntryPointDestination = Join-Path $script:tempRoot 'missing-entrypoint-destination'
        $inv=[pscustomobject]@{ArtifactPath=$script:artifactPath;ArtifactFormat='zip';Settings=[ordered]@{destinationPath=$missingEntryPointDestination;entryPoint='missing.exe'}}
        $spec=&$script:installerCommand -Invocation $inv
        $processResult = InModuleScope Wintainium.Core -Parameters @{ ExecutablePath=$spec.ExecutablePath; Arguments=$spec.Arguments } {
            Invoke-WintainiumInstallerProcess -FilePath $ExecutablePath -ArgumentList $Arguments -TimeoutMilliseconds 30000
        }

        $processResult.Status | Should -Be 'Failed'
        $processResult.ExitCode | Should -Not -Be 0
        $processResult.StandardError | Should -Match 'Expected portable ZIP entry point was not extracted'
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
