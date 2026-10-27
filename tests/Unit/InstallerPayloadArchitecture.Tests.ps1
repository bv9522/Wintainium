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

    It 'requires successful SHA256 verification before architecture-risk evaluation' {
        $path = Join-Path $TestDrive 'setup.exe'
        New-TestPortableExecutable -Path $path -Architecture x64
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
        $result.ReasonCode | Should -Be 'VerifiedArtifactRequired'
    }
}

Describe 'Wintainium unknown-architecture EXE decision candidates' {
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
