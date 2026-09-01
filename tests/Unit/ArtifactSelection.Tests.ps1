$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium artifact selection' {
    It 'prefers an exact architecture over neutral' {
        $artifacts=@([pscustomobject]@{ Uri='https://example.test/neutral.msi'; Format='msi'; Architecture='neutral' },[pscustomobject]@{ Uri='https://example.test/x64.msi'; Format='msi'; Architecture='x64' })
        $release=[pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=$artifacts }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest;MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/x64.msi'
    }

    It 'uses manifest format order after architecture compatibility' {
        $artifacts=@([pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64' },[pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi'; Architecture='x64' })
        $release=[pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=$artifacts }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest;MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app.msi'
    }

    It 'uses input order as the final deterministic tie breaker' {
        $artifacts=@([pscustomobject]@{ Uri='https://example.test/first.msi'; Format='msi'; Architecture='x64' },[pscustomobject]@{ Uri='https://example.test/second.msi'; Format='msi'; Architecture='x64' })
        $release=[pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=$artifacts }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest;MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/first.msi'
    }

    It 'returns no selection when no artifact is eligible' {
        $artifacts=@([pscustomobject]@{ Uri='https://example.test/app.x86.msi'; Format='msi'; Architecture='x86' })
        $release=[pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=$artifacts }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest;MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact | Should -BeNullOrEmpty
        @($result.Observations).Count | Should -Be 1
        $result.Observations[0].ReasonCode | Should -Be 'ArchitectureIncompatible'
    }

    It 'retains all observations while selecting one artifact' {
        $artifacts=@([pscustomobject]@{ Uri='https://example.test/app.zip'; Format='zip'; Architecture='x64' },[pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi'; Architecture='x64' })
        $release=[pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=$artifacts }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest;MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        @($result.Observations).Count | Should -Be 2
        $result.Observations[0].Eligible | Should -BeFalse
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app.msi'
        $result.IsDeterministic | Should -BeTrue
    }

    It 'handles a release with no artifacts deterministically' {
        $release=[pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=@() }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest;MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact | Should -BeNullOrEmpty
        @($result.Observations).Count | Should -Be 0
        $result.IsDeterministic | Should -BeTrue
    }

    It 'prefers exact architecture over a higher-priority format' {
        $artifacts=@([pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi'; Architecture='neutral' },[pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64' })
        $release=[pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=$artifacts }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$false } }
        $result=InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest;MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app.exe'
    }

    It 'selects an explicitly allowed unknown architecture only after exact and neutral candidates' {
        $artifacts=@([pscustomobject]@{ Uri='https://example.test/app.unknown.msi'; Format='msi'; Architecture='unknown' })
        $release=[pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=$artifacts }
        $manifest=[pscustomobject]@{ artifact=[pscustomobject]@{ formats=@('msi','exe'); architectures=@('x64','neutral'); allowUnknownArchitecture=$true } }
        $result=InModuleScope Wintainium.Core -Parameters @{Release=$release;Manifest=$manifest;MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app.unknown.msi'
    }
}
