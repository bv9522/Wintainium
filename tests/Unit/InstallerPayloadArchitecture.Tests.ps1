$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

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

Describe 'Wintainium native static architecture evidence' {
    It 'reads a PE machine header without executing the file' {
        foreach ($architecture in @('x86','x64','arm64')) {
            $path = Join-Path $TestDrive "payload-$architecture.exe"
            New-TestPortableExecutable -Path $path -Architecture $architecture
            (InModuleScope Wintainium.Core -Parameters @{Path=$path} {
                param($Path)
                Get-WintainiumPortableExecutableArchitecture -Path $Path
            }) | Should -Be $architecture
        }
    }

    It 'does not treat the outer executable header as proof of installed payload architecture' {
        $path = Join-Path $TestDrive 'setup.exe'
        New-TestPortableExecutable -Path $path -Architecture x86
        $download = [pscustomobject]@{ Status='Downloaded'; DestinationPath=$path }
        $artifact = [pscustomobject]@{ FileName='setup.exe'; Architecture='unknown' }
        $verification = [pscustomobject]@{ Status='Verified'; Algorithm='SHA256' }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Download=$download; Artifact=$artifact; Verification=$verification
        } {
            param($Download,$Artifact,$Verification)
            Resolve-WintainiumInstallerPayloadArchitecture -DownloadResult $Download -SelectedArtifact $Artifact -VerificationResult $Verification -MachineArchitecture 'x64'
        }

        $result.IsSuccessful | Should -BeFalse
        $result.ReasonCode | Should -Be 'ArchitectureRiskDecisionRequired'
        $result.OuterArchitecture | Should -Be 'x86'
        $result.ResolvedArchitecture | Should -BeNullOrEmpty
    }

    It 'allows an explicitly authorized legacy MD5 verification to reach the separate architecture-risk decision' {
        $path = Join-Path $TestDrive 'setup.exe'
        New-TestPortableExecutable -Path $path -Architecture x86
        $download = [pscustomobject]@{ Status='Downloaded'; DestinationPath=$path }
        $artifact = [pscustomobject]@{ FileName='setup.exe'; Architecture='unknown' }
        $verification = [pscustomobject]@{ Status='VerifiedWithReducedAssurance'; Algorithm='MD5' }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Download=$download; Artifact=$artifact; Verification=$verification
        } {
            param($Download,$Artifact,$Verification)
            Resolve-WintainiumInstallerPayloadArchitecture -DownloadResult $Download -SelectedArtifact $Artifact -VerificationResult $Verification -MachineArchitecture 'x64'
        }

        $result.IsSuccessful | Should -BeFalse
        $result.ReasonCode | Should -Be 'ArchitectureRiskDecisionRequired'
        $result.OuterArchitecture | Should -Be 'x86'
    }

    It 'requires successful checksum verification before architecture-risk evaluation' {
        $path = Join-Path $TestDrive 'setup.exe'
        New-TestPortableExecutable -Path $path -Architecture x64
        $download = [pscustomobject]@{ Status='Downloaded'; DestinationPath=$path }
        $artifact = [pscustomobject]@{ FileName='setup.exe'; Architecture='unknown' }
        $verification = [pscustomobject]@{ Status='Failed'; Algorithm='MD5' }

        $result = InModuleScope Wintainium.Core -Parameters @{
            Download=$download; Artifact=$artifact; Verification=$verification
        } {
            param($Download,$Artifact,$Verification)
            Resolve-WintainiumInstallerPayloadArchitecture -DownloadResult $Download -SelectedArtifact $Artifact -VerificationResult $Verification -MachineArchitecture 'x64'
        }

        $result.IsSuccessful | Should -BeFalse
        $result.ReasonCode | Should -Be 'VerifiedArtifactRequired'
    }
}

Describe 'Wintainium unknown-architecture artifact decision candidates' {
    It 'allows a SHA256-backed unknown EXE to reach the explicit risk-decision step without an external inspector' {
        $manifest = [pscustomobject]@{
            artifact = [pscustomobject]@{ formats=@('exe','zip'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false }
        }
        $exe = [pscustomobject]@{
            Uri='https://example.test/setup.exe'; FileName='setup.exe'; Format='exe'; Architecture='unknown'
            Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('A' * 64) })
        }
        $zip = [pscustomobject]@{
            Uri='https://example.test/app-x64.zip'; FileName='app-x64.zip'; Format='zip'; Architecture='x64'
        }
        $release = [pscustomobject]@{ Version='2.0.0'; Artifacts=@($exe,$zip) }

        $result = InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest} {
            param($Release,$Manifest)
            Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/setup.exe'
        $result.SelectedArtifact.ArchitectureInspectionRequired | Should -BeTrue
    }

    It 'recognizes only well-formed publisher SHA256 or MD5 checksum evidence' {
        $sha256 = [pscustomobject]@{ Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('A' * 64) }) }
        $md5 = [pscustomobject]@{ Hashes=@([pscustomobject]@{ Algorithm='MD5'; Value=('B' * 32) }) }
        $missing = [pscustomobject]@{ FileName='app.zip' }

        (InModuleScope Wintainium.Core -Parameters @{Artifact=$sha256} {
            param($Artifact) Test-WintainiumArtifactHasSupportedChecksum -Artifact $Artifact
        }) | Should -BeTrue
        (InModuleScope Wintainium.Core -Parameters @{Artifact=$md5} {
            param($Artifact) Test-WintainiumArtifactHasSupportedChecksum -Artifact $Artifact
        }) | Should -BeTrue
        (InModuleScope Wintainium.Core -Parameters @{Artifact=$missing} {
            param($Artifact) Test-WintainiumArtifactHasSupportedChecksum -Artifact $Artifact
        }) | Should -BeFalse
    }

    It 'removes unknown-architecture EXEs and preserves compatible alternatives for the fallback choice' {
        $release = [pscustomobject]@{
            Version='2.0.0'
            Artifacts=@(
                [pscustomobject]@{ Uri='https://example.test/setup.exe'; FileName='setup.exe'; Format='exe'; Architecture='unknown' },
                [pscustomobject]@{ Uri='https://example.test/app-unknown.zip'; FileName='app-unknown.zip'; Format='zip'; Architecture='unknown' },
                [pscustomobject]@{ Uri='https://example.test/app-x64.zip'; FileName='app-x64.zip'; Format='zip'; Architecture='x64'; Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('C' * 64) }) }
            )
        }

        $fallback = InModuleScope Wintainium.Core -Parameters @{Releases=@($release)} {
            param($Releases)
            @(Get-WintainiumArchitectureRiskFallbackReleases -Releases $Releases)
        }

        $fallback.Count | Should -Be 1
        @($fallback[0].Artifacts).Count | Should -Be 1
        $fallback[0].Artifacts[0].FileName | Should -Be 'app-x64.zip'

        $manifest = [pscustomobject]@{
            artifact = [pscustomobject]@{ formats=@('exe','zip'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false }
        }
        $selection = InModuleScope Wintainium.Core -Parameters @{Release=$fallback[0];Manifest=$manifest} {
            param($Release,$Manifest)
            Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture 'x64'
        }
        $selection.SelectedArtifact.FileName | Should -Be 'app-x64.zip'
    }

    It 'allows a publisher-declared MD5-backed EXE to reach the separate MD5 and architecture decisions' {
        $manifest = [pscustomobject]@{
            artifact = [pscustomobject]@{ formats=@('exe','zip'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false }
        }
        $exe = [pscustomobject]@{
            Uri='https://example.test/setup.exe'; FileName='setup.exe'; Format='exe'; Architecture='unknown'
            Hashes=@([pscustomobject]@{ Algorithm='MD5'; Value=('A' * 32) })
        }
        $zip = [pscustomobject]@{
            Uri='https://example.test/app-x64.zip'; FileName='app-x64.zip'; Format='zip'; Architecture='x64'
        }
        $release = [pscustomobject]@{ Version='2.0.0'; Artifacts=@($exe,$zip) }

        $result = InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest} {
            param($Release,$Manifest)
            Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/setup.exe'
        $result.SelectedArtifact.ArchitectureInspectionRequired | Should -BeTrue
    }

    It 'applies the same architecture-risk decision to a checksum-backed unknown ZIP artifact' {
        $manifest = [pscustomobject]@{
            artifact = [pscustomobject]@{ formats=@('exe','zip'); architectures=@('x64','neutral'); allowUnknownArchitecture=$true }
        }
        $unknownZip = [pscustomobject]@{
            Uri='https://example.test/app-unknown.zip'; FileName='app-unknown.zip'; Format='zip'; Architecture='unknown'
            Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('D' * 64) })
        }
        $knownZip = [pscustomobject]@{
            Uri='https://example.test/app-x64.zip'; FileName='app-x64.zip'; Format='zip'; Architecture='x64'
            Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=('E' * 64) })
        }
        $release = [pscustomobject]@{ Version='2.0.0'; Artifacts=@($unknownZip,$knownZip) }

        $result = InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest} {
            param($Release,$Manifest)
            Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedArtifact.FileName | Should -Be 'app-unknown.zip'
        $result.SelectedArtifact.ArchitectureInspectionRequired | Should -BeTrue
    }

    It 'uses the compatible ZIP when the unknown EXE has no SHA256 evidence' {
        $manifest = [pscustomobject]@{
            artifact = [pscustomobject]@{ formats=@('exe','zip'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false }
        }
        $exe = [pscustomobject]@{ Uri='https://example.test/setup.exe'; FileName='setup.exe'; Format='exe'; Architecture='unknown' }
        $zip = [pscustomobject]@{ Uri='https://example.test/app-x64.zip'; FileName='app-x64.zip'; Format='zip'; Architecture='x64' }
        $release = [pscustomobject]@{ Version='2.0.0'; Artifacts=@($exe,$zip) }

        $result = InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest} {
            param($Release,$Manifest)
            Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture 'x64'
        }

        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app-x64.zip'
        $result.SelectedArtifact.PSObject.Properties['ArchitectureInspectionRequired'] | Should -BeNullOrEmpty
    }
}
