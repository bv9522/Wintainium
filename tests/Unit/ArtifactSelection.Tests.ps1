$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

function New-TestSelectionManifest {
    param([string[]]$Formats=@('msi','exe'),[string[]]$Architectures=@('x64','neutral'),[bool]$AllowUnknown=$false)
    [pscustomobject]@{ artifact=[pscustomobject]@{ formats=$Formats; architectures=$Architectures; allowUnknownArchitecture=$AllowUnknown } }
}

function New-TestReleaseWithArtifacts {
    param([object[]]$Artifacts)
    [pscustomobject]@{ ReleaseId='release-2.0.0'; Version='2.0.0'; Channel='stable'; Artifacts=$Artifacts }
}

Describe 'Wintainium artifact selection' {
    It 'prefers an exact architecture over neutral' {
        $artifacts=@(
            [pscustomobject]@{ Uri='https://example.test/neutral.msi'; Format='msi'; Architecture='neutral' },
            [pscustomobject]@{ Uri='https://example.test/x64.msi'; Format='msi'; Architecture='x64' }
        )
        $result=InModuleScope Wintainium.Core -Parameters @{Release=(New-TestReleaseWithArtifacts $artifacts);Manifest=(New-TestSelectionManifest);MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/x64.msi'
    }

    It 'uses manifest format order after architecture compatibility' {
        $artifacts=@(
            [pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64' },
            [pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi'; Architecture='x64' }
        )
        $manifest=New-TestSelectionManifest -Formats @('msi','exe')
        $result=InModuleScope Wintainium.Core -Parameters @{Release=(New-TestReleaseWithArtifacts $artifacts);Manifest=$manifest;MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app.msi'
    }

    It 'uses input order as the final deterministic tie breaker' {
        $artifacts=@(
            [pscustomobject]@{ Uri='https://example.test/first.msi'; Format='msi'; Architecture='x64' },
            [pscustomobject]@{ Uri='https://example.test/second.msi'; Format='msi'; Architecture='x64' }
        )
        $result=InModuleScope Wintainium.Core -Parameters @{Release=(New-TestReleaseWithArtifacts $artifacts);Manifest=(New-TestSelectionManifest);MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/first.msi'
    }

    It 'returns no selection when no artifact is eligible' {
        $artifacts=@([pscustomobject]@{ Uri='https://example.test/app.x86.msi'; Format='msi'; Architecture='x86' })
        $result=InModuleScope Wintainium.Core -Parameters @{Release=(New-TestReleaseWithArtifacts $artifacts);Manifest=(New-TestSelectionManifest);MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact | Should -BeNullOrEmpty
        @($result.Observations).Count | Should -Be 1
        $result.Observations[0].ReasonCode | Should -Be 'ArchitectureIncompatible'
    }

    It 'retains all observations while selecting one artifact' {
        $artifacts=@(
            [pscustomobject]@{ Uri='https://example.test/app.zip'; Format='zip'; Architecture='x64' },
            [pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi'; Architecture='x64' }
        )
        $result=InModuleScope Wintainium.Core -Parameters @{Release=(New-TestReleaseWithArtifacts $artifacts);Manifest=(New-TestSelectionManifest);MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        @($result.Observations).Count | Should -Be 2
        $result.Observations[0].Eligible | Should -BeFalse
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app.msi'
        $result.IsDeterministic | Should -BeTrue
    }

    It 'handles a release with no artifacts deterministically' {
        $result=InModuleScope Wintainium.Core -Parameters @{Release=(New-TestReleaseWithArtifacts @());Manifest=(New-TestSelectionManifest);MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact | Should -BeNullOrEmpty
        @($result.Observations).Count | Should -Be 0
        $result.IsDeterministic | Should -BeTrue
    }

    It 'prefers exact architecture over a higher-priority format' {
        $artifacts=@(
            [pscustomobject]@{ Uri='https://example.test/app.msi'; Format='msi'; Architecture='neutral' },
            [pscustomobject]@{ Uri='https://example.test/app.exe'; Format='exe'; Architecture='x64' }
        )
        $result=InModuleScope Wintainium.Core -Parameters @{Release=(New-TestReleaseWithArtifacts $artifacts);Manifest=(New-TestSelectionManifest -Formats @('msi','exe'));MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app.exe'
    }

    It 'selects an explicitly allowed unknown architecture only after exact and neutral candidates' {
        $artifacts=@(
            [pscustomobject]@{ Uri='https://example.test/app.unknown.msi'; Format='msi'; Architecture='unknown' }
        )
        $manifest=New-TestSelectionManifest -AllowUnknown $true
        $result=InModuleScope Wintainium.Core -Parameters @{Release=(New-TestReleaseWithArtifacts $artifacts);Manifest=$manifest;MachineArchitecture='x64'} { param($Release,$Manifest,$MachineArchitecture) Select-WintainiumArtifact -Release $Release -Manifest $Manifest -MachineArchitecture $MachineArchitecture }
        $result.SelectedArtifact.Uri | Should -Be 'https://example.test/app.unknown.msi'
    }
}
