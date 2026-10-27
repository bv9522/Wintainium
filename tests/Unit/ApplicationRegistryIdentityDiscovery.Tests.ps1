BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path $script:testRoot 'core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $script:modulePath -Force
    $script:coreModule = Get-Module -Name Wintainium.Core

    function script:Invoke-RegistryIdentityDiscovery {
        param(
            [Parameter(Mandatory)][string]$ApplicationName,
            [AllowNull()][string]$Publisher,
            [Parameter(Mandatory)][object[]]$RegistryEntries
        )
        & $script:coreModule {
            param($Name, $PublisherValue, $Entries)
            Invoke-RegistryIdentityDiscovery -ApplicationName $Name -Publisher $PublisherValue -RegistryEntries $Entries
        } $ApplicationName $Publisher $RegistryEntries
    }
}

Describe 'Application registry identity discovery' {
    It 'keeps discovery internal while allowing the desktop host to invoke it in module scope' {
        Get-Command Get-WintainiumApplicationRegistryIdentityCandidates -Module Wintainium.Core -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        (& $script:coreModule { Get-Command Get-WintainiumApplicationRegistryIdentityCandidates -CommandType Function }).CommandType | Should -Be 'Function'
    }

    It 'ranks source-name similarities as review-only candidates' {
        $entries = @(
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='Peace'; DisplayName='Peace'; DisplayVersion='1.6.9.11'; Publisher='P.E. Verbeek'; InstallLocation='C:\Program Files\Peace' },
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='EqualizerAPO'; DisplayName='Equalizer APO'; DisplayVersion='1.4.2'; Publisher=''; InstallLocation='C:\Program Files\EqualizerAPO' }
        )

        $result = Invoke-RegistryIdentityDiscovery -ApplicationName 'Peace Equalizer, interface Equalizer APO' -RegistryEntries $entries

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'CandidatesFound'
        $result.CandidateCount | Should -Be 2
        @($result.Candidates | Where-Object { $_.Confidence -eq 'Strong' }).Count | Should -Be 0
        @($result.Candidates | Where-Object { $_.RequiresUserConfirmation }).Count | Should -Be 2
        @($result.Warnings | Where-Object Code -eq 'RegistryIdentityDiscoveryIsNonAuthoritative').Count | Should -Be 1
    }

    It 'recognizes complete numeric version suffixes without substring matching' {
        $entries = @(
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='CoreTemp'; DisplayName='Core Temp 1.20.1'; DisplayVersion='1.20.1'; Publisher='ALCPU' },
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='AMDSettings'; DisplayName='AMD Settings'; DisplayVersion='2026.0423'; Publisher='Advanced Micro Devices, Inc.' }
        )

        $coreTemp = Invoke-RegistryIdentityDiscovery -ApplicationName 'Core Temp' -RegistryEntries $entries
        $coreTemp.Candidates[0].Reason | Should -Be 'CompleteNumericVersionSuffix'
        $coreTemp.Candidates[0].Confidence | Should -Be 'Strong'

        $amd = Invoke-RegistryIdentityDiscovery -ApplicationName 'AMD' -RegistryEntries $entries
        @($amd.Candidates | Where-Object { $_.DisplayName -eq 'AMD Settings' -and $_.Confidence -eq 'Strong' }).Count | Should -Be 0
    }

    It 'requires explicit user confirmation even for a strong exact match' {
        $entries = @(
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='VLC media player'; DisplayName='VLC media player'; DisplayVersion='3.0.23'; Publisher='VideoLAN' }
        )

        $result = Invoke-RegistryIdentityDiscovery -ApplicationName 'VLC media player' -Publisher 'VideoLAN' -RegistryEntries $entries

        $result.Candidates[0].Confidence | Should -Be 'Strong'
        $result.Candidates[0].RequiresUserConfirmation | Should -BeTrue
    }

    It 'returns no candidates when no meaningful identity evidence exists' {
        $entries = @(
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='Unrelated'; DisplayName='Unrelated Utility'; DisplayVersion='1.0'; Publisher='Other Publisher' }
        )

        $result = Invoke-RegistryIdentityDiscovery -ApplicationName 'Audacity' -RegistryEntries $entries

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'NoCandidates'
        $result.CandidateCount | Should -Be 0
    }

    It 'requires confirmation even when publisher information corroborates a similar name' {
        $entries = @(
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='Example'; DisplayName='Example Suite'; DisplayVersion='2.0'; Publisher='Example Publisher' }
        )

        $result = Invoke-RegistryIdentityDiscovery -ApplicationName 'Example Product' -Publisher 'Example Publisher' -RegistryEntries $entries

        $result.CandidateCount | Should -Be 1
        $result.Candidates[0].Confidence | Should -Be 'ReviewOnly'
        $result.Candidates[0].RequiresUserConfirmation | Should -BeTrue
    }
}
