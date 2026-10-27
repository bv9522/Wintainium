$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium static installer payload architecture inspection' {
    It 'reads PE machine architecture without executing the executable' {
function New-TestPortableExecutable {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('x86','x64','arm64')][string]$Architecture
    )

    $bytes = [byte[]]::new(512)
    $bytes[0] = 0x4D
    $bytes[1] = 0x5A
    [BitConverter]::GetBytes([int]0x80).CopyTo($bytes, 0x3C)
    [BitConverter]::GetBytes([uint32]0x00004550).CopyTo($bytes, 0x80)
    $machine = switch ($Architecture) {
        'x86' { [uint16]0x014C }
        'x64' { [uint16]0x8664 }
        'arm64' { [uint16]0xAA64 }
    }
    [BitConverter]::GetBytes($machine).CopyTo($bytes, 0x84)
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

        $x86 = Join-Path $TestDrive 'payload-x86.exe'
        $x64 = Join-Path $TestDrive 'payload-x64.exe'
        $arm64 = Join-Path $TestDrive 'payload-arm64.exe'
        New-TestPortableExecutable -Path $x86 -Architecture x86
        New-TestPortableExecutable -Path $x64 -Architecture x64
        New-TestPortableExecutable -Path $arm64 -Architecture arm64

        (InModuleScope Wintainium.Core -Parameters @{Path=$x86} { param($Path) Get-WintainiumPortableExecutableArchitecture -Path $Path }) | Should -Be 'x86'
        (InModuleScope Wintainium.Core -Parameters @{Path=$x64} { param($Path) Get-WintainiumPortableExecutableArchitecture -Path $Path }) | Should -Be 'x64'
        (InModuleScope Wintainium.Core -Parameters @{Path=$arm64} { param($Path) Get-WintainiumPortableExecutableArchitecture -Path $Path }) | Should -Be 'arm64'
    }

    It 'requires successful SHA256 verification before inspecting an unknown EXE' {
        $path = Join-Path $TestDrive 'setup.exe'
        [System.IO.File]::WriteAllBytes($path, [byte[]]::new(512))
        $download = [pscustomobject]@{ Status='Downloaded'; DestinationPath=$path }
        $artifact = [pscustomobject]@{ FileName='setup.exe'; Architecture='unknown' }
        $verification = [pscustomobject]@{ Status='VerifiedWithReducedAssurance'; Algorithm='MD5' }

        $result = InModuleScope Wintainium.Core -Parameters @{Download=$download;Artifact=$artifact;Verification=$verification} {
            param($Download,$Artifact,$Verification)
            Resolve-WintainiumInstallerPayloadArchitecture -DownloadResult $Download -SelectedArtifact $Artifact -VerificationResult $Verification -MachineArchitecture 'x64' -InnoExtractPath 'test-innoextract'
        }

        $result.IsSuccessful | Should -BeFalse
        $result.ReasonCode | Should -Be 'VerifiedArtifactRequired'
    }

    It 'confirms a dual-architecture payload only when the same application executable is present as x86 and x64' {
        $installerPath = Join-Path $TestDrive 'setup.exe'
        [System.IO.File]::WriteAllBytes($installerPath, [byte[]]::new(512))
        $download = [pscustomobject]@{ Status='Downloaded'; DestinationPath=$installerPath }
        $artifact = [pscustomobject]@{ FileName='setup.exe'; Architecture='unknown' }
        $verification = [pscustomobject]@{ Status='Verified'; Algorithm='SHA256' }

        Mock Invoke-WintainiumInnoExtract {
            param($ToolPath,$InstallerPath,$OutputDirectory)
            $app = Join-Path $OutputDirectory 'app'
            New-Item -ItemType Directory -Path $app -Force | Out-Null
            $x64 = [byte[]]::new(512)
            $x64[0]=0x4D; $x64[1]=0x5A
            [BitConverter]::GetBytes([int]0x80).CopyTo($x64,0x3C)
            [BitConverter]::GetBytes([uint32]0x00004550).CopyTo($x64,0x80)
            [BitConverter]::GetBytes([uint16]0x8664).CopyTo($x64,0x84)
            [System.IO.File]::WriteAllBytes((Join-Path $app 'Example.exe$0'),$x64)
            $x86 = [byte[]]::new(512)
            $x86[0]=0x4D; $x86[1]=0x5A
            [BitConverter]::GetBytes([int]0x80).CopyTo($x86,0x3C)
            [BitConverter]::GetBytes([uint32]0x00004550).CopyTo($x86,0x80)
            [BitConverter]::GetBytes([uint16]0x014C).CopyTo($x86,0x84)
            [System.IO.File]::WriteAllBytes((Join-Path $app 'Example.exe$1'),$x86)
            [pscustomobject]@{ IsSuccessful=$true; ReasonCode='StaticExtractionCompleted'; ErrorMessage=$null }
        } -ModuleName Wintainium.Core

        $result = InModuleScope Wintainium.Core -Parameters @{Download=$download;Artifact=$artifact;Verification=$verification} {
            param($Download,$Artifact,$Verification)
            Resolve-WintainiumInstallerPayloadArchitecture -DownloadResult $Download -SelectedArtifact $Artifact -VerificationResult $Verification -MachineArchitecture 'x64' -InnoExtractPath 'test-innoextract'
        }

        $result.IsSuccessful | Should -BeTrue
        $result.ReasonCode | Should -Be 'DualArchitecturePayloadConfirmed'
        $result.PayloadArchitectures | Should -Contain 'x86'
        $result.PayloadArchitectures | Should -Contain 'x64'
        $result.ResolvedArchitecture | Should -Be 'x64'
    }

    It 'leaves an installer unresolved when the static extractor cannot parse its format' {
        $installerPath = Join-Path $TestDrive 'setup.exe'
        [System.IO.File]::WriteAllBytes($installerPath, [byte[]]::new(512))
        $download = [pscustomobject]@{ Status='Downloaded'; DestinationPath=$installerPath }
        $artifact = [pscustomobject]@{ FileName='setup.exe'; Architecture='unknown' }
        $verification = [pscustomobject]@{ Status='Verified'; Algorithm='SHA256' }

        Mock Invoke-WintainiumInnoExtract {
            [pscustomobject]@{ IsSuccessful=$false; ReasonCode='UnsupportedInstallerFormat'; ErrorMessage='Unsupported format.' }
        } -ModuleName Wintainium.Core

        $result = InModuleScope Wintainium.Core -Parameters @{Download=$download;Artifact=$artifact;Verification=$verification} {
            param($Download,$Artifact,$Verification)
            Resolve-WintainiumInstallerPayloadArchitecture -DownloadResult $Download -SelectedArtifact $Artifact -VerificationResult $Verification -MachineArchitecture 'x64' -InnoExtractPath 'test-innoextract'
        }

        $result.IsSuccessful | Should -BeFalse
        $result.ReasonCode | Should -Be 'UnsupportedInstallerFormat'
        $result.ResolvedArchitecture | Should -BeNullOrEmpty
    }
}

Describe 'Wintainium provisional unknown EXE selection' {
    It 'selects an unknown EXE for inspection only when SHA256 evidence and an inspector are available' {
        $manifest = [pscustomobject]@{
            artifact = [pscustomobject]@{ formats=@('exe','zip'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false }
        }
        $exe = [pscustomobject]@{
            Uri='https://example.test/setup.exe'; FileName='setup.exe'; Format='exe'; Architecture='unknown'
            Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('A' * 64) })
        }
        $zip = [pscustomobject]@{ Uri='https://example.test/app-x64.zip'; FileName='app-x64.zip'; Format='zip'; Architecture='x64' }
        $release = [pscustomobject]@{ Version='2.0.0'; Artifacts=@($exe,$zip) }

        Mock Test-WintainiumInstallerArchitectureInspectionAvailable { $true } -ModuleName Wintainium.Core
        $result = InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest} {
            param($Release,$Manifest)
            Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/setup.exe'
        $result.SelectedArtifact.ArchitectureInspectionRequired | Should -BeTrue
        @($result.Observations | Where-Object { $_.ReasonCode -eq 'ArchitectureInspectionRequired' }).Count | Should -Be 1
    }

    It 'does not promote an unknown EXE without SHA256 evidence' {
        $manifest = [pscustomobject]@{
            artifact = [pscustomobject]@{ formats=@('exe','zip'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false }
        }
        $exe = [pscustomobject]@{ Uri='https://example.test/setup.exe'; FileName='setup.exe'; Format='exe'; Architecture='unknown' }
        $zip = [pscustomobject]@{ Uri='https://example.test/app-x64.zip'; FileName='app-x64.zip'; Format='zip'; Architecture='x64' }
        $release = [pscustomobject]@{ Version='2.0.0'; Artifacts=@($exe,$zip) }

        Mock Test-WintainiumInstallerArchitectureInspectionAvailable { $true } -ModuleName Wintainium.Core
        $result = InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest} {
            param($Release,$Manifest)
            Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app-x64.zip'
        $result.SelectedArtifact.PSObject.Properties['ArchitectureInspectionRequired'] | Should -BeNullOrEmpty
    }
    It 'does not promote an unknown EXE when the optional inspector is unavailable' {
        $manifest = [pscustomobject]@{
            artifact = [pscustomobject]@{ formats=@('exe','zip'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false }
        }
        $exe = [pscustomobject]@{
            Uri='https://example.test/setup.exe'; FileName='setup.exe'; Format='exe'; Architecture='unknown'
            Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('A' * 64) })
        }
        $zip = [pscustomobject]@{ Uri='https://example.test/app-x64.zip'; FileName='app-x64.zip'; Format='zip'; Architecture='x64' }
        $release = [pscustomobject]@{ Version='2.0.0'; Artifacts=@($exe,$zip) }

        Mock Test-WintainiumInstallerArchitectureInspectionAvailable { $false } -ModuleName Wintainium.Core
        $result = InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest} {
            param($Release,$Manifest)
            Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app-x64.zip'
        $result.SelectedArtifact.PSObject.Properties['ArchitectureInspectionRequired'] | Should -BeNullOrEmpty
    }

}


Describe 'Wintainium static inspector discovery' {
    It 'finds the per-user WinGet link when the running process PATH is stale' {
        $localAppData = Join-Path $TestDrive 'user-local-appdata'
        $links = Join-Path $localAppData 'Microsoft\WinGet\Links'
        New-Item -ItemType Directory -Path $links -Force | Out-Null
        $inspector = Join-Path $links 'innoextract.exe'
        [System.IO.File]::WriteAllText($inspector, 'test executable placeholder')

        $originalLocalAppData = $env:LOCALAPPDATA
        try {
            $env:LOCALAPPDATA = $localAppData
            $resolved = InModuleScope Wintainium.Core {
                Mock Get-Command { $null } -ModuleName Wintainium.Core
                Get-WintainiumInstallerArchitectureInspectorPath
            }
            $resolved | Should -Be $inspector
            (InModuleScope Wintainium.Core {
                Mock Get-Command { $null } -ModuleName Wintainium.Core
                Test-WintainiumInstallerArchitectureInspectionAvailable
            }) | Should -BeTrue
        }
        finally {
            $env:LOCALAPPDATA = $originalLocalAppData
        }
    }
}
