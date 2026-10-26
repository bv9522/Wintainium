BeforeAll {
    $testRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $modulePath = Join-Path -Path $testRoot -ChildPath 'core/Wintainium.Core/Wintainium.Core.psd1'

    Import-Module $modulePath -Force
}

Describe 'Wintainium version comparison' {
    It 'preserves an opaque vendor version without inventing ordering' {
        $version = InModuleScope Wintainium.Core {
            New-WintainiumVersionObservation -Version 'release-2026-final'
        }
        $version.Strategy | Should -Be 'Opaque'
        $version.Original | Should -Be 'release-2026-final'
        $version.IsComparable | Should -BeFalse
    }

    It 'recognizes semantic versions and preserves prerelease information' {
        $version = InModuleScope Wintainium.Core {
            New-WintainiumVersionObservation -Version '1.2.3-beta.2'
        }
        $version.Strategy | Should -Be 'SemanticVersion'
        $version.Original | Should -Be '1.2.3-beta.2'
        $version.IsComparable | Should -BeTrue
    }

    It 'compares semantic versions deterministically' {
        $result = InModuleScope Wintainium.Core {
            $older = New-WintainiumVersionObservation -Version '1.2.3'
            $newer = New-WintainiumVersionObservation -Version '1.2.4'
            Compare-WintainiumVersion -Left $older -Right $newer
        }
        $result.Comparison | Should -Be 'Less'
    }

    It 'does not treat semver build metadata as precedence' {
        $result = InModuleScope Wintainium.Core {
            $left = New-WintainiumVersionObservation -Version '1.2.3+build1'
            $right = New-WintainiumVersionObservation -Version '1.2.3+build2'
            Compare-WintainiumVersion -Left $left -Right $right
        }
        $result.Comparison | Should -Be 'Equal'
    }

    It 'compares two-part publisher versions with three-part semantic versions' {
        $result = InModuleScope Wintainium.Core {
            $installed = New-WintainiumVersionObservation -Version '1.20.1'
            $release = New-WintainiumVersionObservation -Version '1.21'
            [pscustomobject]@{
                InstalledStrategy = $installed.Strategy
                ReleaseStrategy = $release.Strategy
                ReleaseNormalized = $release.Normalized
                Comparison = (Compare-WintainiumVersion -Left $release -Right $installed).Comparison
            }
        }
        $result.InstalledStrategy | Should -Be 'SemanticVersion'
        $result.ReleaseStrategy | Should -Be 'SemanticVersion'
        $result.ReleaseNormalized | Should -Be '1.21.0'
        $result.Comparison | Should -Be 'Greater'
    }

    It 'compares System.Version values' {
        $result = InModuleScope Wintainium.Core {
            $older = New-WintainiumVersionObservation -Version '10.0.19045.1'
            $newer = New-WintainiumVersionObservation -Version '10.0.22631.1'
            [pscustomobject]@{
                Strategy = $older.Strategy
                Comparison = (Compare-WintainiumVersion -Left $older -Right $newer).Comparison
            }
        }
        $result.Strategy | Should -Be 'SystemVersion'
        $result.Comparison | Should -Be 'Less'
    }

    It 'compares dotted numeric versions with a single trailing letter suffix' {
        $result = InModuleScope Wintainium.Core {
            $installed = New-WintainiumVersionObservation -Version '11.40b'
            $release = New-WintainiumVersionObservation -Version '11.50a'
            [pscustomobject]@{
                InstalledStrategy = $installed.Strategy
                ReleaseStrategy = $release.Strategy
                Comparison = (Compare-WintainiumVersion -Left $release -Right $installed).Comparison
            }
        }
        $result.InstalledStrategy | Should -Be 'NumericVersionSuffix'
        $result.ReleaseStrategy | Should -Be 'NumericVersionSuffix'
        $result.Comparison | Should -Be 'Greater'
    }

    It 'compares trailing letter suffixes only after equal numeric versions' {
        $result = InModuleScope Wintainium.Core {
            $a = New-WintainiumVersionObservation -Version '11.50a'
            $b = New-WintainiumVersionObservation -Version '11.50b'
            Compare-WintainiumVersion -Left $a -Right $b
        }
        $result.Comparison | Should -Be 'Less'
    }

    It 'does not compare suffixed versions with unsuffixed versions by guessing' {
        $result = InModuleScope Wintainium.Core {
            $suffixed = New-WintainiumVersionObservation -Version '11.50a'
            $plain = New-WintainiumVersionObservation -Version '11.50'
            Compare-WintainiumVersion -Left $suffixed -Right $plain
        }
        $result.Comparison | Should -Be 'Unknown'
        $result.Strategy | Should -Be 'Incompatible'
    }

    It 'returns unknown for opaque values' {
        $result = InModuleScope Wintainium.Core {
            $left = New-WintainiumVersionObservation -Version 'vendor-a'
            $right = New-WintainiumVersionObservation -Version 'vendor-b'
            Compare-WintainiumVersion -Left $left -Right $right
        }
        $result.Comparison | Should -Be 'Unknown'
        $result.IsDeterministic | Should -BeFalse
    }

    It 'returns unknown for incompatible comparison strategies' {
        $result = InModuleScope Wintainium.Core {
            $semantic = New-WintainiumVersionObservation -Version '1.2.3'
            $system = New-WintainiumVersionObservation -Version '1.2.3.4'
            Compare-WintainiumVersion -Left $semantic -Right $system
        }
        $result.Comparison | Should -Be 'Unknown'
        $result.Strategy | Should -Be 'Incompatible'
    }

    It 'returns equal when identical observations use the same strategy' {
        $result = InModuleScope Wintainium.Core {
            $left = New-WintainiumVersionObservation -Version '2.0.0'
            $right = New-WintainiumVersionObservation -Version '2.0.0'
            Compare-WintainiumVersion -Left $left -Right $right
        }
        $result.Comparison | Should -Be 'Equal'
        $result.IsDeterministic | Should -BeTrue
    }
}
