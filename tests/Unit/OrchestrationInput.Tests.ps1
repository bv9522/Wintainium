$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium orchestration input boundary' {
    It 'accepts valid absolute orchestration inputs and creates a correlation identifier' {
        $manifestPath = Join-Path $TestDrive 'application.wintainium.json'
        $downloadRoot = Join-Path $TestDrive 'downloads'

        $result = InModuleScope Wintainium.Core -Parameters @{
            ManifestPath = $manifestPath
            MachineArchitecture = 'x64'
            DownloadRoot = $downloadRoot
        } {
            param($ManifestPath, $MachineArchitecture, $DownloadRoot)
            New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
        }

        $result.IsValid | Should -BeTrue
        $result.Errors | Should -HaveCount 0
        $result.Request.OperationId | Should -Not -BeNullOrEmpty
        [System.Guid]::Parse($result.Request.OperationId) | Should -Not -BeNullOrEmpty
        $result.Request.ManifestPath | Should -Be ([System.IO.Path]::GetFullPath($manifestPath))
        $result.Request.MachineArchitecture | Should -Be 'x64'
        $result.Request.DownloadRoot | Should -Be ([System.IO.Path]::GetFullPath($downloadRoot))
    }

    It 'does not require the manifest file or download directory to exist' {
        $manifestPath = Join-Path $TestDrive 'missing' 'application.wintainium.json'
        $downloadRoot = Join-Path $TestDrive 'not-created-yet'

        $result = InModuleScope Wintainium.Core -Parameters @{
            ManifestPath = $manifestPath
            MachineArchitecture = 'x64'
            DownloadRoot = $downloadRoot
        } {
            param($ManifestPath, $MachineArchitecture, $DownloadRoot)
            New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
        }

        $result.IsValid | Should -BeTrue
        Test-Path -LiteralPath $manifestPath | Should -BeFalse
        Test-Path -LiteralPath $downloadRoot | Should -BeFalse
    }

    It 'rejects a relative manifest path without attempting manifest validation' {
        $result = InModuleScope Wintainium.Core -Parameters @{
            ManifestPath = '.\application.wintainium.json'
            MachineArchitecture = 'x64'
            DownloadRoot = [System.IO.Path]::GetFullPath($TestDrive)
        } {
            param($ManifestPath, $MachineArchitecture, $DownloadRoot)
            New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
        }

        $result.IsValid | Should -BeFalse
        $result.Request | Should -BeNullOrEmpty
        $result.Errors | Should -HaveCount 1
        $result.Errors[0].Code | Should -Be 'OrchestrationManifestPathNotAbsolute'
    }

    It 'rejects a relative download root' {
        $result = InModuleScope Wintainium.Core -Parameters @{
            ManifestPath = [System.IO.Path]::GetFullPath((Join-Path $TestDrive 'application.wintainium.json'))
            MachineArchitecture = 'x64'
            DownloadRoot = '.\downloads'
        } {
            param($ManifestPath, $MachineArchitecture, $DownloadRoot)
            New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
        }

        $result.IsValid | Should -BeFalse
        $result.Errors | Should -HaveCount 1
        $result.Errors[0].Code | Should -Be 'OrchestrationDownloadRootNotAbsolute'
    }

    It 'rejects a whitespace-only machine architecture' {
        $result = InModuleScope Wintainium.Core -Parameters @{
            ManifestPath = [System.IO.Path]::GetFullPath((Join-Path $TestDrive 'application.wintainium.json'))
            MachineArchitecture = '   '
            DownloadRoot = [System.IO.Path]::GetFullPath($TestDrive)
        } {
            param($ManifestPath, $MachineArchitecture, $DownloadRoot)
            New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
        }

        $result.IsValid | Should -BeFalse
        $result.Errors | Should -HaveCount 1
        $result.Errors[0].Code | Should -Be 'OrchestrationMachineArchitectureEmpty'
    }

    It 'trims stable scalar inputs before storing them' {
        $manifestPath = Join-Path $TestDrive 'application.wintainium.json'
        $downloadRoot = Join-Path $TestDrive 'downloads'

        $result = InModuleScope Wintainium.Core -Parameters @{
            ManifestPath = "  $manifestPath  "
            MachineArchitecture = '  ARM64  '
            DownloadRoot = "  $downloadRoot  "
        } {
            param($ManifestPath, $MachineArchitecture, $DownloadRoot)
            New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
        }

        $result.IsValid | Should -BeTrue
        $result.Request.ManifestPath | Should -Be ([System.IO.Path]::GetFullPath($manifestPath))
        $result.Request.MachineArchitecture | Should -Be 'ARM64'
        $result.Request.DownloadRoot | Should -Be ([System.IO.Path]::GetFullPath($downloadRoot))
    }

    It 'generates distinct orchestration operation identifiers for separate requests' {
        $manifestPath = Join-Path $TestDrive 'application.wintainium.json'
        $downloadRoot = Join-Path $TestDrive 'downloads'

        $first = InModuleScope Wintainium.Core -Parameters @{
            ManifestPath = $manifestPath
            MachineArchitecture = 'x64'
            DownloadRoot = $downloadRoot
        } {
            param($ManifestPath, $MachineArchitecture, $DownloadRoot)
            New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
        }

        $second = InModuleScope Wintainium.Core -Parameters @{
            ManifestPath = $manifestPath
            MachineArchitecture = 'x64'
            DownloadRoot = $downloadRoot
        } {
            param($ManifestPath, $MachineArchitecture, $DownloadRoot)
            New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
        }

        $first.Request.OperationId | Should -Not -Be $second.Request.OperationId
    }

    It 'reports all deterministic input errors together' {
        $result = InModuleScope Wintainium.Core -Parameters @{
            ManifestPath = '.\application.wintainium.json'
            MachineArchitecture = '   '
            DownloadRoot = '.\downloads'
        } {
            param($ManifestPath, $MachineArchitecture, $DownloadRoot)
            New-WintainiumOrchestrationRequest -ManifestPath $ManifestPath -MachineArchitecture $MachineArchitecture -DownloadRoot $DownloadRoot
        }

        $result.IsValid | Should -BeFalse
        $result.Request | Should -BeNullOrEmpty
        $result.Errors | Should -HaveCount 3
        @($result.Errors.Code) | Should -Contain 'OrchestrationManifestPathNotAbsolute'
        @($result.Errors.Code) | Should -Contain 'OrchestrationMachineArchitectureEmpty'
        @($result.Errors.Code) | Should -Contain 'OrchestrationDownloadRootNotAbsolute'
    }
}
