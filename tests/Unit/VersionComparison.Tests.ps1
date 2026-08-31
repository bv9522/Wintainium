BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../core/Wintainium.Core/Wintainium.Core.psd1'
    Import-Module $modulePath -Force
}

Describe 'Wintainium version comparison' {
    It 'preserves an opaque vendor version without inventing ordering' {
        $version = New-WintainiumVersionObservation -Version 'release-2026-final'
        $version.Strategy | Should -Be 'Opaque'
        $version.Original | Should -Be 'release-2026-final'
        $version.IsComparable | Should -BeFalse
    }

    It 'recognizes semantic versions and preserves prerelease information' {
        $version = New-WintainiumVersionObservation -Version '1.2.3-beta.2'
        $version.Strategy | Should -Be 'SemanticVersion'
        $version.Original | Should -Be '1.2.3-beta.2'
        $version.IsComparable | Should -BeTrue
    }

    It 'compares semantic versions deterministically' {
        $older = New-WintainiumVersionObservation -Version '1.2.3'
        $newer = New-WintainiumVersionObservation -Version '1.2.4'
        (Compare-WintainiumVersion -Left $older -Right $newer).Comparison | Should -Be 'Less'
    }

    It 'does not treat semver build metadata as precedence' {
        $left = New-WintainiumVersionObservation -Version '1.2.3+build1'
        $right = New-WintainiumVersionObservation -Version '1.2.3+build2'
        (Compare-WintainiumVersion -Left $left -Right $right).Comparison | Should -Be 'Equal'
    }

    It 'compares System.Version values' {
        $older = New-WintainiumVersionObservation -Version '10.0.19045.1'
        $newer = New-WintainiumVersionObservation -Version '10.0.22631.1'
        $older.Strategy | Should -Be 'SystemVersion'
        (Compare-WintainiumVersion -Left $older -Right $newer).Comparison | Should -Be 'Less'
    }

    It 'returns unknown for opaque values' {
        $left = New-WintainiumVersionObservation -Version 'vendor-a'
        $right = New-WintainiumVersionObservation -Version 'vendor-b'
        $result = Compare-WintainiumVersion -Left $left -Right $right
        $result.Comparison | Should -Be 'Unknown'
        $result.IsDeterministic | Should -BeFalse
    }

    It 'returns unknown for incompatible comparison strategies' {
        $semantic = New-WintainiumVersionObservation -Version '1.2.3'
        $system = New-WintainiumVersionObservation -Version '1.2.3.4'
        $result = Compare-WintainiumVersion -Left $semantic -Right $system
        $result.Comparison | Should -Be 'Unknown'
        $result.Strategy | Should -Be 'Incompatible'
    }

    It 'returns equal when identical observations use the same strategy' {
        $left = New-WintainiumVersionObservation -Version '2.0.0'
        $right = New-WintainiumVersionObservation -Version '2.0.0'
        $result = Compare-WintainiumVersion -Left $left -Right $right
        $result.Comparison | Should -Be 'Equal'
        $result.IsDeterministic | Should -BeTrue
    }
}
