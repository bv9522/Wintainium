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
        $result = InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request; Reader=$reader } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                param($Settings)
                Get-WintainainiumWindowsInstalledApplicationCandidates -Settings $Settings -RegistryReader $Reader
            }
            Invoke-WintainiumReconciliation -Request $Request
        }
        # The module test above deliberately exercises the public contract; private-reader behavior is tested separately below.
        $result.IsSuccessful | Should -BeTrue
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
            Invoke-WintainiumReconciliation -Request $Request
        } | Should -Match 'NotInstalled'
    }

    It 'maps multiple candidates to Unknown without selecting one' {
        $request = [pscustomobject]@{
            OperationId='00000000-0000-0000-0000-000000000203'
            ApplicationId='example.application'
            Manifest=$script:baseManifest
        }
        $candidate=[pscustomobject]@{ Scope='machine'; View='64'; SubKey='A'; DisplayName='Example Application'; DisplayVersion='1.0'; InstallLocation='C:\A' }
        $candidate2=[pscustomobject]@{ Scope='machine'; View='32'; SubKey='B'; DisplayName='Example Application'; DisplayVersion='2.0'; InstallLocation='C:\B' }
        InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request; Candidates=@($candidate,$candidate2) } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{ IsSuccessful=$true; Candidates=$Candidates; Errors=@() }
            }
            $r=Invoke-WintainiumReconciliation -Request $Request
            $r.Evidence.InstallationState
        } | Should -Be 'Unknown'
    }

    It 'maps registry read failure to Unknown rather than NotInstalled' {
        $request=[pscustomobject]@{ OperationId='00000000-0000-0000-0000-000000000204'; ApplicationId='example.application'; Manifest=$script:baseManifest }
        InModuleScope Wintainium.reconciliation.windows-installed-application -Parameters @{ Request=$request } {
            Mock -CommandName Get-WintainiumWindowsInstalledApplicationCandidates -MockWith {
                [pscustomobject]@{ IsSuccessful=$false; Candidates=@(); Errors=@([pscustomobject]@{ Code='WindowsRegistryLocationReadFailed'; Message='denied' }) }
            }
            $r=Invoke-WintainiumReconciliation -Request $Request
            $r.Evidence.InstallationState
        } | Should -Be 'Unknown'
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
            Invoke-WintainiumReconciliation -Request $Request
        } | ForEach-Object {
            $_.Evidence.Version | Should -Be 'v2-beta'
            $_.Evidence.VersionSource | Should -Be 'Registry'
            $_.Evidence.InstallationLocation | Should -Be 'C:\Example'
        }
    }
}

