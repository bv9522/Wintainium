BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

    Import-Module $script:modulePath -Force 
}

Describe 'Wintainium public result contract' {
    It 'keeps the public update result property set stable at the command boundary' {
        InModuleScope Wintainium.Core {
            Mock Invoke-WintainiumApplicationUpdateLifecycle {
                [pscustomobject][ordered]@{
                    OperationId='operation-10b-contract'
                    IsSuccessful=$false
                    WasCancelled=$false
                    StageResults=@(
                        [pscustomobject]@{
                            Stage=[pscustomobject]@{ Sequence=1; Name='ManifestValidation' }
                            Execution=[pscustomobject]@{
                                IsSuccessful=$false
                                WasCancelled=$false
                                Result=[pscustomobject]@{
                                    IsSuccessful=$false
                                    Status='ValidationFailed'
                                    Manifest=[pscustomobject]@{ Id='example.app' }
                                    Errors=@([pscustomobject]@{ Code='ManifestValidationFailed'; Message='Invalid manifest.' })
                                    Warnings=@()
                                    LogEvents=@()
                                    Error=[pscustomobject]@{ Code='ManifestValidationFailed'; Message='Invalid manifest.' }
                                }
                            }
                        }
                    )
                    Error=[pscustomobject]@{ Code='ManifestValidationFailed'; Message='Invalid manifest.' }
                }
            }
            $result = Invoke-WintainiumApplicationUpdate -ManifestPath 'C:\Wintainium\example.json' -StateRoot 'C:\Wintainium\state' -MachineArchitecture 'x64' -DownloadRoot 'C:\Wintainium\downloads'
            @($result.PSObject.Properties.Name | Sort-Object) | Should -Be @(
                'ApplicationId'
                'Error'
                'Errors'
                'IsSuccessful'
                'LogEvents'
                'OperationId'
                'Stages'
                'Status'
                'Warnings'
                'WasCancelled'
            )
            $result.Status | Should -Be 'Failed'
            $result.ApplicationId | Should -Be 'example.app'
            $result.Stages[0].Error.Code | Should -Be 'ManifestValidationFailed'
            $result.Errors[0].Code | Should -Be 'ManifestValidationFailed'
            $result.PSObject.Properties.Name | Should -Not -Contain 'State'
            $result.PSObject.Properties.Name | Should -Not -Contain 'Request'
            Should -Invoke Invoke-WintainiumApplicationUpdateLifecycle -Times 1 -Exactly
        }
    }
    It 'returns a structured manifest-discovery result with correlation and diagnostics fields' {
        $path = Join-Path -Path $TestDrive -ChildPath 'manifests'
        New-Item -Path $path -ItemType Directory -Force | Out-Null

        $result = Get-WintainiumManifest -Path $path
        $parsedOperationId = [guid]::Empty

        $result -is [string] | Should -BeFalse
        $result.PSObject.Properties['OperationId'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['IsSuccessful'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Candidates'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['ManifestPaths'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Manifests'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Errors'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Warnings'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['LogEvents'] | Should -Not -BeNullOrEmpty
        [guid]::TryParse([string]$result.OperationId, [ref]$parsedOperationId) | Should -BeTrue
        @($result.Errors) | Should -BeNullOrEmpty
        @($result.Warnings) | Should -BeNullOrEmpty
        @($result.LogEvents).Count | Should -BeGreaterThan 0
    }

    It 'keeps the documented top-level result property sets stable for all supported commands' {
        $manifestPath = Join-Path -Path $TestDrive -ChildPath 'missing.wintainium.json'
        $manifestCollection = Join-Path -Path $TestDrive -ChildPath 'manifests'
        New-Item -Path $manifestCollection -ItemType Directory -Force | Out-Null

        $results = @(
            (Get-WintainiumManifest -Path $manifestCollection)
            (Test-WintainiumApplicationDefinition -ManifestPath $manifestPath)
            (Get-WintainiumApplicationRelease -ManifestPath $manifestPath)
        )

        $expectedPropertySets = @(
            ,@('OperationId', 'IsSuccessful', 'Candidates', 'ManifestPaths', 'Manifests', 'Errors', 'Warnings', 'LogEvents')
            ,@('OperationId', 'IsValid', 'Manifest', 'ProviderPlugin', 'InstallerPlugin', 'ReconciliationPlugin', 'Errors', 'Warnings', 'LogEvents')
            ,@('OperationId', 'IsSuccessful', 'Status', 'Manifest', 'ProviderPlugin', 'Releases', 'Errors', 'Warnings', 'LogEvents')
        )

        for ($index = 0; $index -lt $results.Count; $index++) {
            $actual = @($results[$index].PSObject.Properties.Name | Sort-Object)
            $expected = @($expectedPropertySets[$index] | Sort-Object)
            $actual | Should -Be $expected
        }
    }

    It 'returns structured validation failure data without requiring exception-text parsing' {
        $manifestPath = Join-Path -Path $TestDrive -ChildPath 'missing.wintainium.json'

        $result = Test-WintainiumApplicationDefinition -ManifestPath $manifestPath

        $result -is [string] | Should -BeFalse
        $result.IsValid | Should -BeFalse
        $result.PSObject.Properties['OperationId'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Manifest'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['ProviderPlugin'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['InstallerPlugin'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Errors'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Warnings'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['LogEvents'] | Should -Not -BeNullOrEmpty
        @($result.Errors).Count | Should -BeGreaterThan 0
        $result.Errors[0].PSObject.Properties['Code'] | Should -Not -BeNullOrEmpty
        $result.Errors[0].PSObject.Properties['Message'] | Should -Not -BeNullOrEmpty
    }

    It 'returns structured release-discovery failure data with the validation operation correlation identifier' {
        $manifestPath = Join-Path -Path $TestDrive -ChildPath 'missing.wintainium.json'

        $result = Get-WintainiumApplicationRelease -ManifestPath $manifestPath

        $result -is [string] | Should -BeFalse
        $result.IsSuccessful | Should -BeFalse
        $result.Status | Should -Be 'ApplicationDefinitionInvalid'
        $result.PSObject.Properties['OperationId'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Manifest'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['ProviderPlugin'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Releases'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Errors'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Warnings'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['LogEvents'] | Should -Not -BeNullOrEmpty
        @($result.Errors).Count | Should -BeGreaterThan 0
        @($result.Releases).Count | Should -Be 0
    }

    It 'uses structured error objects rather than formatted error strings' {
        $manifestPath = Join-Path -Path $TestDrive -ChildPath 'missing.wintainium.json'
        $results = @(
            (Test-WintainiumApplicationDefinition -ManifestPath $manifestPath)
            (Get-WintainiumApplicationRelease -ManifestPath $manifestPath)
        )

        foreach ($result in $results) {
            foreach ($errorRecord in @($result.Errors)) {
                $errorRecord -is [string] | Should -BeFalse
                $errorRecord.PSObject.Properties['Code'] | Should -Not -BeNullOrEmpty
                $errorRecord.PSObject.Properties['Message'] | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'does not require clients to parse formatted output for structured result consumption' {
        $path = Join-Path -Path $TestDrive -ChildPath 'manifests'
        New-Item -Path $path -ItemType Directory -Force | Out-Null

        $result = Get-WintainiumManifest -Path $path
        $json = $result | ConvertTo-Json -Depth 10
        $roundTrip = $json | ConvertFrom-Json

        $roundTrip.OperationId | Should -Be $result.OperationId
        $roundTrip.IsSuccessful | Should -Be $result.IsSuccessful
        @($roundTrip.Errors) | Should -BeNullOrEmpty
    }
}
