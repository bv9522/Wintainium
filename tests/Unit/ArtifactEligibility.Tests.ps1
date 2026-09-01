$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium artifact eligibility' {
    It 'accepts a permitted format with an exact architecture match' {
        $artifact=[pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi'; Architecture='x64' }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Artifact=$artifact;Manifest=$manifest;MachineArchitecture='x64'} { param($Artifact,$Manifest,$MachineArchitecture) Test-WintainiumArtifactEligibility -Artifact $Artifact -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.Eligible | Should -BeTrue
        $result.ReasonCode | Should -Be 'Eligible'
    }

    It 'rejects a format not permitted by the manifest' {
        $artifact=[pscustomobject]@{ Uri='https://example.test/app.zip'; Format='zip'; Architecture='x64' }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Artifact=$artifact;Manifest=$manifest;MachineArchitecture='x64'} { param($Artifact,$Manifest,$MachineArchitecture) Test-WintainiumArtifactEligibility -Artifact $Artifact -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'FormatNotPermitted'
    }

    It 'accepts neutral architecture on a known machine' {
        $artifact=[pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi'; Architecture='neutral' }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Artifact=$artifact;Manifest=$manifest;MachineArchitecture='arm64'} { param($Artifact,$Manifest,$MachineArchitecture) Test-WintainiumArtifactEligibility -Artifact $Artifact -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.Eligible | Should -BeTrue
    }

    It 'rejects a mismatched architecture' {
        $artifact=[pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi'; Architecture='x86' }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x86','x64'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Artifact=$artifact;Manifest=$manifest;MachineArchitecture='x64'} { param($Artifact,$Manifest,$MachineArchitecture) Test-WintainiumArtifactEligibility -Artifact $Artifact -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'ArchitectureIncompatible'
    }

    It 'rejects unknown architecture unless explicitly allowed' {
        $artifact=[pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi'; Architecture='unknown' }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Artifact=$artifact;Manifest=$manifest;MachineArchitecture='x64'} { param($Artifact,$Manifest,$MachineArchitecture) Test-WintainiumArtifactEligibility -Artifact $Artifact -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.Eligible | Should -BeFalse
        $result.ReasonCode | Should -Be 'ArchitectureNotPermitted'
    }

    It 'accepts unknown architecture only when explicitly allowed' {
        $artifact=[pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi'; Architecture='unknown' }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$true } }
        $result=InModuleScope Wintainium.Core -Parameters @{Artifact=$artifact;Manifest=$manifest;MachineArchitecture='x64'} { param($Artifact,$Manifest,$MachineArchitecture) Test-WintainiumArtifactEligibility -Artifact $Artifact -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.Eligible | Should -BeTrue
    }

    It 'rejects missing format metadata' {
        $artifact=[pscustomobject]@{ Uri='https://example.test/app'; Architecture='x64' }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Artifact=$artifact;Manifest=$manifest;MachineArchitecture='x64'} { param($Artifact,$Manifest,$MachineArchitecture) Test-WintainiumArtifactEligibility -Artifact $Artifact -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.ReasonCode | Should -Be 'FormatMissing'
    }

    It 'rejects missing architecture metadata' {
        $artifact=[pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi' }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Artifact=$artifact;Manifest=$manifest;MachineArchitecture='x64'} { param($Artifact,$Manifest,$MachineArchitecture) Test-WintainiumArtifactEligibility -Artifact $Artifact -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.ReasonCode | Should -Be 'ArchitectureMissing'
    }

    It 'normalizes format and architecture case before policy evaluation' {
        $artifact=[pscustomobject]@{ Uri='https://example.test/app.MSI'; Format='MSI'; Architecture='X64' }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Artifact=$artifact;Manifest=$manifest;MachineArchitecture='x64'} { param($Artifact,$Manifest,$MachineArchitecture) Test-WintainiumArtifactEligibility -Artifact $Artifact -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.Eligible | Should -BeTrue
        $result.Format | Should -Be 'msi'
        $result.Architecture | Should -Be 'x64'
    }

    It 'does not treat artifact metadata as execution instructions' {
        $artifact=[pscustomobject]@{ Uri='powershell.exe -Command Write-Host BAD'; Format='msi'; Architecture='x64' }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Artifact=$artifact;Manifest=$manifest;MachineArchitecture='x64'} { param($Artifact,$Manifest,$MachineArchitecture) Test-WintainiumArtifactEligibility -Artifact $Artifact -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.Eligible | Should -BeTrue
        $result.Artifact.Uri | Should -Be 'powershell.exe -Command Write-Host BAD'
    }
}
