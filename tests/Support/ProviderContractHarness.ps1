function Register-WintainiumProviderContractTests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Provider
    )

    if (-not $Provider) {
        throw 'A resolved provider descriptor is required.'
    }

    $newRequest = {
        param(
            [string]$OperationId,
            [hashtable]$Settings = @{}
        )

        [pscustomobject]@{
            OperationId = if ($OperationId) { $OperationId } else { [guid]::NewGuid().ToString() }
            ApplicationId = 'example.application'
            ProviderId = $Provider.PluginId
            RequiredContractVersion = '1'
            Settings = $Settings
            DiscoveryContext = @{}
        }
    }

    It 'accepts a provider descriptor with the required contract identity and capabilities' {
        $Provider.PluginType | Should -Be 'Provider'
        @($Provider.ContractVersions) | Should -Contain '1'
        $Provider.Capabilities.releaseDiscovery | Should -BeTrue
        $Provider.Capabilities.artifactDiscovery | Should -BeTrue
        $Provider.EntryPoint | Should -Match '\.psm1$'
    }

    It 'executes the provider through the fixed Core operation boundary' {
        $request = & $newRequest

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $Provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result | Should -Not -BeNullOrEmpty
        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
        $result.OperationId | Should -Be $request.OperationId
    }

    It 'returns normalized release and artifact data' {
        $request = & $newRequest

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $Provider; Request = $request } {
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
        $artifact.Hashes | Should -HaveCount 1
        $artifact.Hashes[0].Algorithm | Should -Be 'SHA256'
        $artifact.Hashes[0].Value | Should -Match '^[0-9a-fA-F]{64}$'
    }

    It 'preserves operation correlation in provider log events' {
        $request = & $newRequest

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $Provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        @($result.LogEvents) | Should -Not -BeNullOrEmpty
        @($result.LogEvents | Where-Object { $_.OperationId -ne $request.OperationId }) | Should -HaveCount 0
    }

    It 'treats NoReleasesFound as a successful provider outcome' {
        $request = & $newRequest -Settings @{ mode = 'empty' }

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $Provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'NoReleasesFound'
        @($result.Releases) | Should -HaveCount 0
        @($result.Errors) | Should -HaveCount 0
    }

    It 'preserves structured provider-declared failures' {
        $request = & $newRequest -Settings @{ mode = 'failure' }

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $Provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'SourceUnavailable'
        @($result.Errors.Code) | Should -Contain 'ProviderSourceUnavailable'
    }

    It 'converts provider exceptions into structured Core failures' {
        $request = & $newRequest -Settings @{ mode = 'throw' }

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $Provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ProviderInternalError'
        @($result.Errors.Code) | Should -Contain 'ProviderInternalError'
    }

    It 'rejects a result whose operation identifier does not match the request' {
        $request = & $newRequest -Settings @{ mode = 'bad-operation-id' }

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $Provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ProviderResultInvalid'
        @($result.Errors.Code) | Should -Contain 'ProviderResultOperationIdMismatch'
    }

    It 'rejects malformed normalized release data' {
        $request = & $newRequest -Settings @{ mode = 'bad-release' }

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $Provider; Request = $Request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ProviderResultInvalid'
        @($result.Errors.Code) | Should -Contain 'ProviderResultReleaseInvalid'
    }

    It 'does not require upstream network access' {
        $request = & $newRequest

        $result = InModuleScope Wintainium.Core -Parameters @{ Provider = $Provider; Request = $request } {
            Invoke-WintainiumProviderOperation -Provider $Provider -Request $Request
        }

        $result.IsSuccessful | Should -BeTrue
        $result.Status | Should -Be 'Success'
    }
}
