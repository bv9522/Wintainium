BeforeAll {
    $script:testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $script:testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

    Import-Module $script:modulePath -Force
}

Describe 'Wintainium public result contract' {
    It 'returns a structured manifest-discovery result with correlation and diagnostics fields' {
        $path = Join-Path -Path $TestDrive -ChildPath 'manifests'
        New-Item -Path $path -ItemType Directory | Out-Null

        $result = Get-WintainiumManifest -Path $path
        $parsedOperationId = [guid]::Empty

        $result -is [string] | Should -BeFalse
        $result.PSObject.Properties['OperationId'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['IsSuccessful'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Errors'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Warnings'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['LogEvents'] | Should -Not -BeNullOrEmpty
        [guid]::TryParse([string]$result.OperationId, [ref]$parsedOperationId) | Should -BeTrue
    }

    It 'returns structured validation failure data without requiring exception-text parsing' {
        $manifestPath = Join-Path -Path $TestDrive -ChildPath 'missing.wintainium.json'

        $result = Test-WintainiumApplicationDefinition -ManifestPath $manifestPath

        $result -is [string] | Should -BeFalse
        $result.IsValid | Should -BeFalse
        $result.PSObject.Properties['OperationId'] | Should -Not -BeNullOrEmpty
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
        $result.PSObject.Properties['Errors'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['Warnings'] | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties['LogEvents'] | Should -Not -BeNullOrEmpty
        @($result.Errors).Count | Should -BeGreaterThan 0
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
}
