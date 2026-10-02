$modulePath = Join-Path $PSScriptRoot '..\..\core\Wintainium.Core\Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium download artifact lifecycle' {
    It 'removes a completed artifact and its empty operation directory' {
        InModuleScope Wintainium.Core {
            $root = Join-Path $TestDrive 'downloads'
            $operationId = [guid]::NewGuid().ToString()
            $directory = Join-Path $root (Join-Path 'operations' $operationId)
            [System.IO.Directory]::CreateDirectory($directory) | Out-Null
            $destination = Join-Path $directory 'example.exe'
            [System.IO.File]::WriteAllText($destination, 'artifact')

            $result = Invoke-WintainiumDownloadArtifactCleanup -DownloadResult ([pscustomobject]@{
                OperationId=$operationId
                Status='Downloaded'
                ArtifactDirectory=$directory
                DestinationPath=$destination
            }) -DownloadRoot $root -Outcome Completed

            $result.IsSuccessful | Should -BeTrue
            $result.Status | Should -Be 'Removed'
            $result.Removed | Should -BeTrue
            $result.Retained | Should -BeFalse
            Test-Path -LiteralPath $destination | Should -BeFalse
            Test-Path -LiteralPath $directory | Should -BeFalse
        }
    }

    It 'retains a completed artifact when the lifecycle fails' {
        InModuleScope Wintainium.Core {
            $root = Join-Path $TestDrive 'downloads'
            $operationId = [guid]::NewGuid().ToString()
            $directory = Join-Path $root (Join-Path 'operations' $operationId)
            [System.IO.Directory]::CreateDirectory($directory) | Out-Null
            $destination = Join-Path $directory 'example.exe'
            [System.IO.File]::WriteAllText($destination, 'artifact')

            $result = Invoke-WintainiumDownloadArtifactCleanup -DownloadResult ([pscustomobject]@{
                OperationId=$operationId
                Status='Downloaded'
                ArtifactDirectory=$directory
                DestinationPath=$destination
            }) -DownloadRoot $root -Outcome Failed

            $result.IsSuccessful | Should -BeTrue
            $result.Status | Should -Be 'Retained'
            $result.Retained | Should -BeTrue
            Test-Path -LiteralPath $destination | Should -BeTrue
        }
    }

    It 'retains a completed artifact when the lifecycle is cancelled' {
        InModuleScope Wintainium.Core {
            $root = Join-Path $TestDrive 'downloads'
            $operationId = [guid]::NewGuid().ToString()
            $directory = Join-Path $root (Join-Path 'operations' $operationId)
            [System.IO.Directory]::CreateDirectory($directory) | Out-Null
            $destination = Join-Path $directory 'example.exe'
            [System.IO.File]::WriteAllText($destination, 'artifact')

            $result = Invoke-WintainiumDownloadArtifactCleanup -DownloadResult ([pscustomobject]@{
                OperationId=$operationId
                Status='Downloaded'
                ArtifactDirectory=$directory
                DestinationPath=$destination
            }) -DownloadRoot $root -Outcome Cancelled

            $result.IsSuccessful | Should -BeTrue
            $result.Status | Should -Be 'Retained'
            Test-Path -LiteralPath $destination | Should -BeTrue
        }
    }

    It 'never deletes a path outside the Core-controlled download root' {
        InModuleScope Wintainium.Core {
            $root = Join-Path $TestDrive 'downloads'
            $outside = Join-Path $TestDrive 'outside.exe'
            [System.IO.File]::WriteAllText($outside, 'artifact')

            $result = Invoke-WintainiumDownloadArtifactCleanup -DownloadResult ([pscustomobject]@{
                OperationId=[guid]::NewGuid().ToString()
                Status='Downloaded'
                DestinationPath=$outside
            }) -DownloadRoot $root -Outcome Completed

            $result.IsSuccessful | Should -BeTrue
            $result.Status | Should -Be 'NotManaged'
            Test-Path -LiteralPath $outside | Should -BeTrue
        }
    }

    It 'does not fail when the artifact is already absent after a successful lifecycle' {
        InModuleScope Wintainium.Core {
            $root = Join-Path $TestDrive 'downloads'
            $directory = Join-Path $root (Join-Path 'operations' ([guid]::NewGuid().ToString()))
            [System.IO.Directory]::CreateDirectory($directory) | Out-Null
            $destination = Join-Path $directory 'example.exe'

            $result = Invoke-WintainiumDownloadArtifactCleanup -DownloadResult ([pscustomobject]@{
                OperationId=[guid]::NewGuid().ToString()
                Status='Downloaded'
                ArtifactDirectory=$directory
                DestinationPath=$destination
            }) -DownloadRoot $root -Outcome Completed

            $result.IsSuccessful | Should -BeTrue
            $result.Status | Should -Be 'AlreadyAbsent'
        }
    }
}
