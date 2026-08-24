function Register-WintainiumProviderContractTests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Provider,

        [Parameter(Mandatory)]
        [scriptblock]$RequestFactory
    )

    if (-not $Provider) {
        throw 'A resolved provider descriptor is required.'
    }

    if (-not $RequestFactory) {
        throw 'A provider request factory is required.'
    }

    # Pester v6 executes It blocks after this function has returned. Persist the
    # inputs into the caller's scope so the deferred test blocks can still see them.
    Set-Variable -Name WintainiumProviderContractRequestFactory -Value $RequestFactory -Scope 1
    Set-Variable -Name WintainiumProviderContractUnderTest -Value $Provider -Scope 1

    It 'accepts a provider descriptor with the required contract identity and capabilities' {
        $WintainiumProviderContractUnderTest.PluginType | Should -Be 'Provider'
        @($WintainiumProviderContractUnderTest.ContractVersions) | Should -Contain '1'
        $WintainiumProviderContractUnderTest.Capabilities.releaseDiscovery | Should -BeTrue
        $WintainiumProviderContractUnderTest.Capabilities.artifactDiscovery | Should -BeTrue
        $WintainiumProviderContractUnderTest.EntryPoint | Should -Match '\.psm1$'
    }

    It 'executes the provider through the fixed Core operation boundary' {
        $request = & $WintainiumProviderContractRequestFactory

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $WintainiumProviderContractUnderTest; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result | Should -Not -BeNullOrEmpty
        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        $result.OperationId | Should -Be $request.OperationId
    }

    It 'returns normalized release and artifact data' {
        $request = & $WintainiumProviderContractRequestFactory

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $WintainiumProviderContractUnderTest; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.Releases | Should -HaveCount 1
        $release = $result.Releases[0]
        $release.ReleaseId | Should -Not -BeNullOrEmpty
        $release.Version | Should -Not -BeNullOrEmpty
        $release.Channel | Should -BeIn @('stable', 'prerelease')
        $release.Artifacts | Should -HaveCount 1

        $artifact = $release.Artifacts[0]
        $artifact.Uri | Should -Match '^https://'
        $artifact.FileName | Should -Not -BeNullOrEmpty
        $artifact.Format | Should -Be 'zip'
        $artifact.Architecture | Should -Be 'x64'
    }

    It 'preserves operation correlation in provider log events' {
        $request = & $WintainiumProviderContractRequestFactory

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $WintainiumProviderContractUnderTest; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        @($result.LogEvents) | Should -Not -BeNullOrEmpty
        @($result.LogEvents | Where-Object { $_.OperationId -ne $request.OperationId }) | Should -HaveCount 0
    }
}
