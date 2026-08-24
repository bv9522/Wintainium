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

    # Pester v6 executes It blocks after this function has returned. Capture the
    # supplied inputs in explicit closures rather than relying on dynamic scope.
    $providerUnderTest = $Provider
    $requestFactoryUnderTest = $RequestFactory

    It 'accepts a provider descriptor with the required contract identity and capabilities' ({
        $providerUnderTest.PluginType | Should -Be 'Provider'
        @($providerUnderTest.ContractVersions) | Should -Contain '1'
        $providerUnderTest.Capabilities.releaseDiscovery | Should -BeTrue
        $providerUnderTest.Capabilities.artifactDiscovery | Should -BeTrue
        $providerUnderTest.EntryPoint | Should -Match '\.psm1$'
    }.GetNewClosure())

    It 'executes the provider through the fixed Core operation boundary' ({
        $request = & $requestFactoryUnderTest

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $providerUnderTest; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result | Should -Not -BeNullOrEmpty
        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        $result.OperationId | Should -Be $request.OperationId
    }.GetNewClosure())

    It 'returns normalized release and artifact data' ({
        $request = & $requestFactoryUnderTest

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $providerUnderTest; Request = $request } {
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
    }.GetNewClosure())

    It 'preserves operation correlation in provider log events' ({
        $request = & $requestFactoryUnderTest

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $providerUnderTest; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        @($result.LogEvents) | Should -Not -BeNullOrEmpty
        @($result.LogEvents | Where-Object { $_.OperationId -ne $request.OperationId }) | Should -HaveCount 0
    }.GetNewClosure())
}
