$testRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Split-Path -Parent $testRoot) 'core/Wintainium.Core/Wintainium.Core.psd1'
Import-Module $modulePath -Force

Describe 'Wintainium artifact verification' {
    BeforeEach {
        $path = Join-Path $TestDrive 'artifact.bin'
        [IO.File]::WriteAllText($path, 'Wintainium verification fixture')
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        $artifact = [pscustomobject]@{ Uri='https://example.test/app.msi'; FileName='app.msi'; Hashes=@([pscustomobject]@{ Algorithm='SHA256'; Value=$hash }) }
        $download = [pscustomobject]@{ OperationId='operation-1'; Status='Downloaded'; DestinationPath=$path; Uri=$artifact.Uri; FileName=$artifact.FileName }
    }

    It 'verifies a completed download when the SHA256 claim matches' {
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.Status | Should -Be 'Verified'
        $result.FailureKind | Should -BeNullOrEmpty
        $result.Algorithm | Should -Be 'SHA256'
        $result.ExpectedHash | Should -Be $result.ActualHash
        $result.OperationId | Should -Be 'operation-1'
    }

    It 'preserves an explicitly supplied OperationId' {
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact -OperationId 'operation-explicit' }
        $result.Status | Should -Be 'Verified'
        $result.OperationId | Should -Be 'operation-explicit'
    }

    It 'rejects a hash mismatch' {
        $artifact.Hashes[0].Value = ('0' * 64)
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'HashMismatch'
        $result.Algorithm | Should -Be 'SHA256'
        $result.ExpectedHash | Should -Be ('0' * 64)
        $result.ActualHash | Should -Be $hash
    }

    It 'rejects a download that did not complete' {
        $download.Status = 'Failed'
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.FailureKind | Should -Be 'DownloadNotCompleted'
    }

    It 'rejects a download result missing Status' {
        $download.PSObject.Properties.Remove('Status')
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'InputInvalid'
    }

    It 'rejects a completed download with a missing destination' {
        $download.DestinationPath = Join-Path $TestDrive 'missing.bin'
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'DestinationMissing'
    }

    It 'rejects missing hash evidence instead of treating download success as verification' {
        $artifact.Hashes = $null
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.FailureKind | Should -Be 'VerificationMetadataMissing'
    }

    It 'continues to reject absent hash evidence even when legacy MD5 is authorized' {
        $artifact.Hashes = @()
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact -AllowLegacyMd5Verification }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'VerificationMetadataMissing'
    }
    It 'rejects unsupported-only algorithms' {
        $artifact.Hashes = @([pscustomobject]@{ Algorithm='MD5'; Value=('0' * 32) })
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.FailureKind | Should -Be 'UnsupportedVerificationAlgorithm'
    }

    It 'does not accept publisher MD5 without explicit user authorization' {
        $md5 = (Get-FileHash -LiteralPath $path -Algorithm MD5).Hash
        $artifact.Hashes = @([pscustomobject]@{ Algorithm='MD5'; Value=$md5; Source='OfficialDownloadPageChecksum' })
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'UnsupportedVerificationAlgorithm'
    }

    It 'accepts a matching publisher-declared MD5 only with explicit authorization and marks reduced assurance' {
        $md5 = (Get-FileHash -LiteralPath $path -Algorithm MD5).Hash
        $artifact.Hashes = @([pscustomobject]@{ Algorithm='MD5'; Value=$md5; Source='OfficialDownloadPageChecksum' })
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact -AllowLegacyMd5Verification }
        $result.Status | Should -Be 'VerifiedWithReducedAssurance'
        $result.IsSuccessful | Should -BeTrue
        $result.Algorithm | Should -Be 'MD5'
        $result.ExpectedHash | Should -Be $md5
        $result.ActualHash | Should -Be $md5
        $result.VerificationLevel | Should -Be 'ReducedAssurance'
        $result.UserAuthorized | Should -BeTrue
    }

    It 'rejects a mismatched publisher MD5 even when the user authorizes legacy verification' {
        $artifact.Hashes = @([pscustomobject]@{ Algorithm='MD5'; Value=('0' * 32); Source='OfficialDownloadPageChecksum' })
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact -AllowLegacyMd5Verification }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'HashMismatch'
        $result.Algorithm | Should -Be 'MD5'
    }

    It 'does not accept MD5 from an unknown metadata source even with user authorization' {
        $md5 = (Get-FileHash -LiteralPath $path -Algorithm MD5).Hash
        $artifact.Hashes = @([pscustomobject]@{ Algorithm='MD5'; Value=$md5; Source='UntrustedMetadata' })
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact -AllowLegacyMd5Verification }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'UnsupportedVerificationAlgorithm'
    }
    It 'rejects malformed SHA256 evidence' {
        $artifact.Hashes = @([pscustomobject]@{ Algorithm='SHA256'; Value='not-a-digest' })
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.FailureKind | Should -Be 'VerificationMetadataInvalid'
    }

    It 'rejects a hash claim missing its required fields' {
        $artifact.Hashes = @([pscustomobject]@{ Algorithm='SHA256' })
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'VerificationMetadataInvalid'
    }

    It 'supports dictionary-style hash metadata' {
        $artifact.Hashes = @{ sha256 = $hash }
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.Status | Should -Be 'Verified'
        $result.OperationId | Should -Be 'operation-1'
    }

    It 'requires every declared SHA256 claim to match' {
        $artifact.Hashes = @(
            [pscustomobject]@{ Algorithm='SHA256'; Value=$hash }
            [pscustomobject]@{ Algorithm='sha256'; Value=('0' * 64) }
        )
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.Status | Should -Be 'Failed'
        $result.FailureKind | Should -Be 'HashMismatch'
    }

    It 'does not execute the artifact while verifying it' {
        $artifact.Uri = 'powershell.exe -Command Write-Host BAD'
        $result = InModuleScope Wintainium.Core -Parameters @{ DownloadResult=$download; SelectedArtifact=$artifact } { param($DownloadResult,$SelectedArtifact) Invoke-WintainiumArtifactVerification -DownloadResult $DownloadResult -SelectedArtifact $SelectedArtifact }
        $result.Status | Should -Be 'Verified'
    }
}