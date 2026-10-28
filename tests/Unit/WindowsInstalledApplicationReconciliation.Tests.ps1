BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path $script:testRoot 'plugins/Wintainium.reconciliation.windows-installed-application/Wintainium.reconciliation.windows-installed-application.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'Windows installed-application reconciliation plugin' {
    BeforeAll {
        $script:baseManifest = [pscustomobject][ordered]@{
            reconciliation = [pscustomobject][ordered]@{
                settings = [pscustomobject][ordered]@{
                    registry = [pscustomobject][ordered]@{
                        locations = @([pscustomobject]@{ scope='machine'; view='64' })
                        match = @([pscustomobject]@{ value='DisplayName'; equals='Example Application' })
                    }
                }
            }
        }
    }

    It 'returns Installed evidence for one exact match' {
        $request = [pscustomobject]@{
            OperationId='00000000-0000-0000-0000-000000000201'
            ApplicationId='example.application'
            Manifest=$script:baseManifest
        }
        $reader = {
            param($location)
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='Example'; DisplayName='Example Application'; DisplayVersion='2.4.1'; Publisher='Example Publisher'; InstallLocation='C:\Program Files\Example' }
        }
        $observation = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Settings=$script:baseManifest.reconciliation.settings; Reader=$reader } {
            Get-WintainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader
        }
        $observation.IsSuccessful | Should -BeTrue
        $observation.Candidates.Count | Should -Be 1
        $observation.Candidates[0].DisplayVersion | Should -Be '2.4.1'

        InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request; Candidate=$observation.Candidates[0] } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{ IsSuccessful=$true; Candidates=@($Candidate); Errors=@() }
            }
            $result = Invoke-WintainiumReconciliation -Request $Request
            $result.Evidence.InstallationState | Should -Be 'Installed'
            $result.Evidence.Version | Should -Be '2.4.1'
            $result.Evidence.InstallationLocation | Should -Be 'C:\Program Files\Example'
        }
    }

    It 'maps zero successful candidates to NotInstalled' {
        $request = [pscustomobject]@{
            OperationId='00000000-0000-0000-0000-000000000202'
            ApplicationId='example.application'
            Manifest=$script:baseManifest
        }
        InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{ IsSuccessful=$true; Candidates=@(); Errors=@() }
            }
            $result = Invoke-WintainiumReconciliation -Request $Request
            $result.Evidence.InstallationState | Should -Be 'NotInstalled'
        }
    }

    It 'maps multiple candidates to Unknown without selecting one' {
        $request = [pscustomobject]@{
            OperationId='00000000-0000-0000-0000-000000000203'
            ApplicationId='example.application'
            Manifest=$script:baseManifest
        }
        $candidate=[pscustomobject]@{ Scope='machine'; View='64'; SubKey='A'; DisplayName='Example Application'; DisplayVersion='1.0'; InstallLocation='C:\A' }
        $candidate2=[pscustomobject]@{ Scope='machine'; View='32'; SubKey='B'; DisplayName='Example Application'; DisplayVersion='2.0'; InstallLocation='C:\B' }
        $r = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request; Candidates=@($candidate,$candidate2) } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{ IsSuccessful=$true; Candidates=$Candidates; Errors=@() }
            }
            Invoke-WintainiumReconciliation -Request $Request
        }
        $r.IsSuccessful | Should -BeTrue
        $r.Status | Should -Be 'Unknown'
        $r.Evidence.InstallationState | Should -Be 'Unknown'
        @($r.Warnings | Where-Object Code -eq 'WindowsReconciliationAmbiguous').Count | Should -Be 1
        $ambiguity = @($r.Warnings | Where-Object Code -eq 'WindowsReconciliationAmbiguous')[0]
        $ambiguity.Message | Should -Match 'Multiple uninstall registrations matched'
        $ambiguity.CandidateCount | Should -Be 2
        $ambiguity.MatchMode | Should -Be 'all'
        $ambiguity.RegistryLocationCount | Should -Be 1
        $r.Evidence.PSObject.Properties.Name | Should -Not -Contain 'Version'
    }

    It 'maps registry read failure to Unknown rather than NotInstalled' {
        $request=[pscustomobject]@{ OperationId='00000000-0000-0000-0000-000000000204'; ApplicationId='example.application'; Manifest=$script:baseManifest }
        $r = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{ IsSuccessful=$false; Candidates=@(); Errors=@([pscustomobject]@{ Code='WindowsRegistryLocationReadFailed'; Message='denied'; Scope='machine'; View='64' }) }
            }
            Invoke-WintainiumReconciliation -Request $Request
        }
        $r.IsSuccessful | Should -BeTrue
        $r.Status | Should -Be 'Unknown'
        $r.Evidence.InstallationState | Should -Be 'Unknown'
        @($r.Warnings | Where-Object Code -eq 'WindowsRegistryLocationReadFailed').Count | Should -Be 1
        $readFailure = @($r.Warnings | Where-Object Code -eq 'WindowsRegistryLocationReadFailed')[0]
        $readFailure.OperationId | Should -Be $request.OperationId
        $readFailure.Message | Should -Be 'denied'
        $summary = @($r.Warnings | Where-Object Code -eq 'WindowsReconciliationEvidenceIncomplete')
        $summary.Count | Should -Be 1
        $summary[0].CandidateCount | Should -Be 0
        $summary[0].MatchMode | Should -Be 'all'
        $summary[0].RegistryLocationCount | Should -Be 1
        $summary[0].RegistryReadFailureCount | Should -Be 1
        $summary[0].Message | Should -Match 'cannot safely conclude'
    }

    It 'rejects missing settings as a structured configuration failure' {
        $request=[pscustomobject]@{ OperationId='00000000-0000-0000-0000-000000000205'; ApplicationId='example.application'; Manifest=[pscustomobject]@{ reconciliation=[pscustomobject]@{} } }
        $r=Invoke-WintainiumReconciliation -Request $request
        $r.IsSuccessful | Should -BeFalse
        $r.Status | Should -Be 'InvalidSettings'
        @($r.Errors.Code) | Should -Contain 'WindowsReconciliationSettingsMissing'
    }

    It 'does not infer architecture from the registry view' {
        $request=[pscustomobject]@{ OperationId='00000000-0000-0000-0000-000000000206'; ApplicationId='example.application'; Manifest=$script:baseManifest }
        InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{ IsSuccessful=$true; Candidates=@([pscustomobject]@{ Scope='machine'; View='32'; SubKey='Example'; DisplayName='Example Application'; DisplayVersion='1.0'; InstallLocation=$null }); Errors=@() }
            }
            Invoke-WintainiumReconciliation -Request $Request
        } | Should -Not -BeNullOrEmpty
        $r = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{ IsSuccessful=$true; Candidates=@([pscustomobject]@{ Scope='machine'; View='32'; SubKey='Example'; DisplayName='Example Application'; DisplayVersion='1.0'; InstallLocation=$null }); Errors=@() }
            }
            Invoke-WintainiumReconciliation -Request $Request
        }
        $r.Evidence.PSObject.Properties.Name | Should -Not -Contain 'Architecture'
    }

    It 'copies DisplayVersion and InstallLocation without comparing versions' {
        $request=[pscustomobject]@{ OperationId='00000000-0000-0000-0000-000000000207'; ApplicationId='example.application'; Manifest=$script:baseManifest }
        InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{ IsSuccessful=$true; Candidates=@([pscustomobject]@{ Scope='machine'; View='64'; SubKey='Example'; DisplayName='Example Application'; DisplayVersion='v2-beta'; InstallLocation='C:\Example' }); Errors=@() }
            }
            Mock -CommandName Get-WintainiumWindowsExecutableVersion -MockWith { $null }
            Invoke-WintainiumReconciliation -Request $Request
        } | ForEach-Object {
            $_.Evidence.Version | Should -Be 'v2-beta'
            $_.Evidence.VersionSource | Should -Be 'Registry'
            $_.Evidence.InstallationLocation | Should -Be 'C:\Example'
        }
    }

    It 'normalizes a four-component executable build version against a three-component registry version' {
        InModuleScope Wintainium.reconciliation.windows-installed-application {
            ConvertTo-WintainiumComparableExecutableVersion -Version '1.21.0.207' -RegistryVersion '1.20.1' | Should -Be '1.21.0'
            ConvertTo-WintainiumComparableExecutableVersion -Version '1.21.0' -RegistryVersion '1.20.1' | Should -Be '1.21.0'
            ConvertTo-WintainiumComparableExecutableVersion -Version '1.21.0.207' -RegistryVersion '1.20.1.150' | Should -Be '1.21.0.207'
        }
    }

    It 'reads file version metadata from an executable matching the registry display name' {
        $installLocation = Join-Path $TestDrive 'Core Temp'
        New-Item -ItemType Directory -Path $installLocation -Force | Out-Null
        $executablePath = Join-Path $installLocation 'Core Temp.exe'
        Copy-Item -LiteralPath (Join-Path $PSHOME 'pwsh.exe') -Destination $executablePath -Force

        $result = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Location=$installLocation } {
            Get-WintainiumWindowsExecutableVersion -InstallationLocation $Location -DisplayName 'Core Temp 1.20.1' -RegistryVersion '1.20.1'
        }

        $result | Should -Not -BeNullOrEmpty
        $result.Version | Should -Not -BeNullOrEmpty
        $result.Path | Should -Be $executablePath
    }

    It 'prefers matching executable version metadata over a stale uninstall registry version' {
        $request=[pscustomobject]@{ OperationId='00000000-0000-0000-0000-000000000208'; ApplicationId='web.www.alcpu.com.coretemp'; Manifest=$script:baseManifest }
        InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{ IsSuccessful=$true; Candidates=@([pscustomobject]@{ Scope='machine'; View='64'; SubKey='CoreTemp'; DisplayName='Core Temp 1.20.1'; DisplayVersion='1.20.1'; InstallLocation='C:\Program Files\Core Temp' }); Errors=@() }
            }
            Mock -CommandName Get-WintainiumWindowsExecutableVersion -MockWith {
                [pscustomobject]@{ Version='1.21.0'; Path='C:\Program Files\Core Temp\Core Temp.exe' }
            }
            $result = Invoke-WintainiumReconciliation -Request $Request
            $result.Evidence.Version | Should -Be '1.21.0'
            $result.Evidence.VersionSource | Should -Be 'ExecutableFileVersion'
            $result.Evidence.InstallationLocation | Should -Be 'C:\Program Files\Core Temp'
        }
    }

    It 'supports any-match reconciliation when one registry identity matches' {
        $settings = [pscustomobject][ordered]@{
            registry = [pscustomobject][ordered]@{
                matchMode = 'any'
                locations = @([pscustomobject]@{ scope='machine'; view='64' })
                match = @(
                    [pscustomobject]@{ value='DisplayName'; equals='7-Zip' }
                    [pscustomobject]@{ value='subkey'; equals='7-Zip' }
                )
            }
        }
        $reader = {
            param($location)
            [pscustomobject]@{
                Scope='machine'; View='64'; SubKey='7-Zip'
                DisplayName='7-Zip 26.03 (x64 edition)'
                DisplayVersion='26.03'; Publisher='Igor Pavlov'; InstallLocation='C:\Program Files\7-Zip'
            }
        }

        $observation = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Settings=$settings; Reader=$reader } {
            Get-WintainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader
        }

        $observation.IsSuccessful | Should -BeTrue
        $observation.Candidates.Count | Should -Be 1
        $observation.Candidates[0].SubKey | Should -Be '7-Zip'
    }

    It 'matches a complete numeric version suffix without enabling substring matching' {
        $settings = [pscustomobject][ordered]@{
            registry = [pscustomobject][ordered]@{
                matchMode = 'any'
                locations = @([pscustomobject]@{ scope='machine'; view='64' })
                match = @([pscustomobject]@{ value='DisplayName'; equals='GIMP'; matchType='nameOrVersionSuffix' })
            }
        }
        $reader = {
            param($location)
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='GIMP-2_is1'; DisplayName='GIMP 2.10.38'; DisplayVersion='2.10.38' }
        }
        $observation = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Settings=$settings; Reader=$reader } {
            Get-WintainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader
        }
        $observation.Candidates.Count | Should -Be 1

        $unrelatedReader = {
            param($location)
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='AMD Settings'; DisplayName='AMD Settings'; DisplayVersion='2026.0423' }
        }
        $unrelated = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Settings=([pscustomobject]@{ registry=[pscustomobject]@{ matchMode='any'; locations=@([pscustomobject]@{scope='machine';view='64'}); match=@([pscustomobject]@{value='DisplayName';equals='AMD';matchType='nameOrVersionSuffix'}) } }); Reader=$unrelatedReader } {
            Get-WintainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader
        }
        $unrelated.Candidates.Count | Should -Be 0
    }

    It 'applies conservative version suffix normalization to legacy name predicates' {
        $settings = [pscustomobject][ordered]@{
            registry = [pscustomobject][ordered]@{
                matchMode = 'any'
                locations = @([pscustomobject]@{ scope='machine'; view='64' })
                match = @([pscustomobject]@{ value='DisplayName'; equals='Core Temp' })
            }
        }
        $reader = {
            param($location)
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='{086D343F-8E78-4AFC-81AC-D6D414AFD8AC}_is1'; DisplayName='Core Temp 1.20.1'; DisplayVersion='1.20.1' }
        }
        $observation = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Settings=$settings; Reader=$reader } {
            Get-WintainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader
        }
        $observation.Candidates.Count | Should -Be 1
    }

    It 'supports explicitly declared exact aliases' {
        $settings = [pscustomobject][ordered]@{
            registry = [pscustomobject][ordered]@{
                matchMode = 'any'
                locations = @([pscustomobject]@{ scope='machine'; view='64' })
                match = @([pscustomobject]@{ value='DisplayName'; equals='Attribute Changer'; aliases=@('Attribute Changer Classic') })
            }
        }
        $reader = {
            param($location)
            [pscustomobject]@{ Scope='machine'; View='64'; SubKey='{27263813-8BDE-4CD2-84D3-02536743428A}_is1'; DisplayName='Attribute Changer Classic'; DisplayVersion='11.40b' }
        }
        $observation = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Settings=$settings; Reader=$reader } {
            Get-WintainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader
        }
        $observation.Candidates.Count | Should -Be 1
    }

    It 'retains all-match semantics when match mode is omitted' {
        $settings = [pscustomobject][ordered]@{
            registry = [pscustomobject][ordered]@{
                locations = @([pscustomobject]@{ scope='machine'; view='64' })
                match = @(
                    [pscustomobject]@{ value='DisplayName'; equals='Example Application' }
                    [pscustomobject]@{ value='subkey'; equals='Example' }
                )
            }
        }
        $reader = {
            param($location)
            [pscustomobject]@{
                Scope='machine'; View='64'; SubKey='Example'
                DisplayName='Example Application'; DisplayVersion='1.0'
            }
        }

        $observation = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Settings=$settings; Reader=$reader } {
            Get-WintainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader
        }

        $observation.Candidates.Count | Should -Be 1
    }


    It 'reports installed architecture only when an exact-name executable provides PE evidence' {
        $installLocation = Join-Path $TestDrive 'Architecture Evidence'
        New-Item -ItemType Directory -Path $installLocation -Force | Out-Null
        $executablePath = Join-Path $installLocation 'Example Application.exe'
        Copy-Item -LiteralPath (Join-Path $PSHOME 'pwsh.exe') -Destination $executablePath -Force

        $architecture = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Location=$installLocation } {
            Get-WintainiumWindowsExecutableArchitecture -InstallationLocation $Location -DisplayName 'Example Application 2.4.1'
        }

        $architecture | Should -BeIn @('x86','x64','arm64')
    }

    It 'does not infer installed architecture from the registry view or unrelated executable names' {
        $installLocation = Join-Path $TestDrive 'Unrelated Architecture Evidence'
        New-Item -ItemType Directory -Path $installLocation -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSHOME 'pwsh.exe') -Destination (Join-Path $installLocation 'Other.exe') -Force

        $architecture = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Location=$installLocation } {
            Get-WintainiumWindowsExecutableArchitecture -InstallationLocation $Location -DisplayName 'Example Application 2.4.1'
        }

        $architecture | Should -BeNullOrEmpty
    }

    It 'includes architecture evidence only when the executable inspection succeeds' {
        $request=[pscustomobject]@{ OperationId='00000000-0000-0000-0000-000000000209'; ApplicationId='example.application'; Manifest=$script:baseManifest }
        $r = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{ IsSuccessful=$true; Candidates=@([pscustomobject]@{ Scope='machine'; View='32'; SubKey='Example'; DisplayName='Example Application'; DisplayVersion='1.0'; InstallLocation='C:\Example' }); Errors=@() }
            }
            Mock -CommandName Get-WintainiumWindowsExecutableVersion -MockWith { $null }
            Mock -CommandName Get-WintainiumWindowsExecutableArchitecture -MockWith { 'x64' }
            Invoke-WintainiumReconciliation -Request $Request
        }

        $r.Evidence.Architecture | Should -Be 'x64'
    }


    It 'resolves a shortened Windows product name from the primary source phrase and corroborating registry metadata' {
        $settings = [pscustomobject]@{
            registry = [pscustomobject]@{
                matchMode = 'any'
                locations = @([pscustomobject]@{ scope='machine'; view='64' })
                match = @(
                    [pscustomobject]@{ value='DisplayName'; equals='Peace Equalizer, interface Equalizer APO'; matchType='exact' }
                    [pscustomobject]@{ value='subkey'; equals='Peace Equalizer, interface Equalizer APO'; matchType='exact' }
                )
            }
        }
        $reader = {
            param($location)
            @(
                [pscustomobject]@{
                    Scope='machine'; View='64'; SubKey='Peace'; DisplayName='Peace'
                    DisplayVersion='1.6.9.11'; Publisher='P.E. Verbeek'
                    InstallLocation='C:\Program Files\Peace'
                    UninstallString='"C:\Program Files\Peace\unins000.exe"'
                },
                [pscustomobject]@{
                    Scope='machine'; View='64'; SubKey='EqualizerAPO'; DisplayName='Equalizer APO'
                    DisplayVersion='1.4.2'; Publisher=''
                    InstallLocation='C:\Program Files\EqualizerAPO'
                }
            )
        }

        $result = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{
            Settings=$settings; Reader=$reader; Name='Peace Equalizer, interface Equalizer APO'; Publisher='Browse Files at SourceForge.net'
        } {
            Get-WintainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader -ApplicationName $Name -ApplicationPublisher $Publisher
        }

        $result.Candidates.Count | Should -Be 1
        $result.Candidates[0].DisplayName | Should -Be 'Peace'
        $result.Candidates[0].IdentityConfidence | Should -Be 'Strong'
        $result.Candidates[0].IdentityScore | Should -BeGreaterOrEqual 70
        @($result.Candidates[0].IdentityEvidence) | Should -Contain 'MeaningfulDisplayNameTokensContainedInPrimaryPhrase'
        @($result.Candidates[0].IdentityEvidence) | Should -Contain 'InstallLocationNameCorroborated'
        @($result.Candidates[0].IdentityEvidence) | Should -Contain 'DisplayNameAndSubKeyConsistent'
    }

    It 'keeps a weak partial-name candidate non-authoritative' {
        $settings = [pscustomobject]@{
            registry = [pscustomobject]@{
                matchMode = 'any'
                locations = @([pscustomobject]@{ scope='machine'; view='64' })
                match = @([pscustomobject]@{ value='DisplayName'; equals='AMD'; matchType='exact' })
            }
        }
        $reader = {
            param($location)
            [pscustomobject]@{
                Scope='machine'; View='64'; SubKey='AMD Settings'; DisplayName='AMD Settings'
                DisplayVersion='2026.0423'; Publisher='Advanced Micro Devices, Inc.'
            }
        }

        $result = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{
            Settings=$settings; Reader=$reader; Name='AMD'
        } {
            Get-WintainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader -ApplicationName $Name
        }

        $result.Candidates.Count | Should -Be 1
        $result.Candidates[0].IdentityConfidence | Should -Be 'ReviewOnly'
        $result.Candidates[0].IdentityScore | Should -BeLessThan 70
    }

    It 'returns multiple review-only candidates when the available name evidence is ambiguous' {
        $settings = [pscustomobject]@{
            registry = [pscustomobject]@{
                matchMode = 'any'
                locations = @([pscustomobject]@{ scope='machine'; view='64' })
                match = @([pscustomobject]@{ value='DisplayName'; equals='Acme Equalizer'; matchType='exact' })
            }
        }
        $reader = {
            param($location)
            @(
                [pscustomobject]@{ Scope='machine'; View='64'; SubKey='Acme'; DisplayName='Acme'; InstallLocation='C:\Program Files\Acme' },
                [pscustomobject]@{ Scope='machine'; View='64'; SubKey='Equalizer'; DisplayName='Equalizer'; InstallLocation='C:\Program Files\Equalizer' }
            )
        }

        $result = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{
            Settings=$settings; Reader=$reader; Name='Acme Equalizer'
        } {
            Get-WintainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader -ApplicationName $Name
        }

        $result.Candidates.Count | Should -Be 2
        @($result.Candidates | Where-Object IdentityConfidence -eq 'ReviewOnly').Count | Should -Be 2
    }

    It 'does not promote a review-only identity result to Installed' {
        $request = [pscustomobject]@{
            OperationId='00000000-0000-0000-0000-000000000209'
            ApplicationId='example.application'
            Manifest=[pscustomobject]@{
                name='AMD'
                publisher='Advanced Micro Devices, Inc.'
                reconciliation=[pscustomobject]@{ settings=[pscustomobject]@{ registry=[pscustomobject]@{ matchMode='any'; locations=@([pscustomobject]@{scope='machine';view='64'}); match=@([pscustomobject]@{value='DisplayName';equals='AMD';matchType='exact'}) } } }
            }
        }
        $result = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{
                    IsSuccessful=$true
                    Candidates=@([pscustomobject]@{
                        Scope='machine'; View='64'; SubKey='AMD Settings'; DisplayName='AMD Settings'
                        DisplayVersion='2026.0423'; IdentityScore=31; IdentityConfidence='ReviewOnly'
                        IdentityEvidence=@('SharedMeaningfulNameTokens')
                    })
                    Errors=@()
                }
            }
            Invoke-WintainiumReconciliation -Request $Request
        }

        $result.Status | Should -Be 'Unknown'
        $result.Evidence.InstallationState | Should -Be 'Unknown'
        @($result.Warnings | Where-Object Code -eq 'WindowsReconciliationIdentityRequiresConfirmation').Count | Should -Be 1
    }


    It 'uses publisher and matching product website metadata as corroborating evidence' {
        $settings = [pscustomobject]@{
            registry = [pscustomobject]@{
                matchMode = 'any'
                locations = @([pscustomobject]@{ scope='machine'; view='64' })
                match = @([pscustomobject]@{ value='DisplayName'; equals='Old Example Name'; matchType='exact' })
            }
        }
        $reader = {
            param($location)
            [pscustomobject]@{
                Scope='machine'; View='64'; SubKey='Example Product'; DisplayName='Example Product'
                DisplayVersion='2.0'; Publisher='Example Publisher'
                InstallLocation='C:\Program Files\Example Product'
                DisplayIcon='"C:\Program Files\Example Product\Example Product.exe",0'
                URLInfoAbout='https://example.com/about'
                UninstallString='"C:\Program Files\Example Product\uninstall.exe"'
            }
        }

        $result = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{
            Settings=$settings; Reader=$reader; Name='Example Product'; Publisher='Example Publisher'; Homepage='https://example.com/product'
        } {
            Get-WintainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader -ApplicationName $Name -ApplicationPublisher $Publisher -ApplicationHomepage $Homepage
        }

        $result.Candidates.Count | Should -Be 1
        @($result.Candidates[0].IdentityEvidence) | Should -Contain 'NormalizedDisplayNameExact'
        @($result.Candidates[0].IdentityEvidence) | Should -Contain 'PublisherCorroborated'
        @($result.Candidates[0].IdentityEvidence) | Should -Contain 'PublisherWebsiteHostCorroborated'
        @($result.Candidates[0].IdentityEvidence) | Should -Contain 'DisplayIconNameCorroborated'
    }


    It 'normalizes punctuation, numeric versions, and recognized architecture suffixes' {
        InModuleScope Wintainium.reconciliation.windows-installed-application {
            ConvertTo-WintainiumIdentityName -Value '7-Zip 26.03 (x64 edition)' | Should -Be '7 zip'
            ConvertTo-WintainiumIdentityName -Value 'Core Temp 1.20.1' | Should -Be 'core temp'
            ConvertTo-WintainiumIdentityName -Value 'AMD Settings' | Should -Be 'amd settings'
        }
    }

}

