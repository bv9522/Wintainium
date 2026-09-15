[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $PackageRoot -ErrorAction Stop).Path

foreach ($excludedDirectory in @('.git', '.github', 'tests')) {
    if (Test-Path -LiteralPath (Join-Path $root $excludedDirectory)) {
        throw "Release package validation failed: development directory '$excludedDirectory' is present."
    }
}

$expectedRootFiles = @(
    'ARCHITECTURE.md'
    'CHANGELOG.md'
    'PROJECT.md'
    'README.md'
    'ROADMAP.md'
)

$expectedRootDirectories = @(
    'core'
    'docs'
    'manifests'
    'plugins'
    'schemas'
)

foreach ($relativePath in $expectedRootFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) {
        throw "Release package validation failed: required root asset '$relativePath' is missing."
    }
}

foreach ($relativePath in $expectedRootDirectories) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Container)) {
        throw "Release package validation failed: required package directory '$relativePath' is missing."
    }
}

$allowedRootEntries = @($expectedRootFiles + $expectedRootDirectories)
foreach ($entry in Get-ChildItem -LiteralPath $root -Force) {
    if ($entry.Name -notin $allowedRootEntries) {
        throw "Release package validation failed: unexpected root entry '$($entry.Name)' is present."
    }
}

$moduleManifestPath = Join-Path $root 'core/Wintainium.Core/Wintainium.Core.psd1'
$moduleManifest = Import-PowerShellDataFile -LiteralPath $moduleManifestPath

if ([string]::IsNullOrWhiteSpace([string]$moduleManifest.ModuleVersion)) {
    throw 'Release package validation failed: Core module ModuleVersion is missing.'
}

if ([string]$moduleManifest.ModuleVersion -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
    throw "Release package validation failed: invalid ModuleVersion '$($moduleManifest.ModuleVersion)'."
}

$rootModule = [string]$moduleManifest.RootModule
if ([string]::IsNullOrWhiteSpace($rootModule)) {
    throw 'Release package validation failed: RootModule is missing.'
}

if (-not (Test-Path -LiteralPath (Join-Path (Split-Path $moduleManifestPath -Parent) $rootModule) -PathType Leaf)) {
    throw "Release package validation failed: RootModule '$rootModule' was not found."
}

$expectedExports = @(
    'Get-WintainiumManifest'
    'Test-WintainiumApplicationDefinition'
    'Get-WintainiumApplicationRelease'
)
$actualExports = @($moduleManifest.FunctionsToExport | ForEach-Object { [string]$_ })
if (($actualExports -join "`n") -cne ($expectedExports -join "`n")) {
    throw 'Release package validation failed: exported public command surface does not match the supported contract.'
}

$requiredFiles = @(
    'README.md'
    'PROJECT.md'
    'ARCHITECTURE.md'
    'ROADMAP.md'
    'CHANGELOG.md'
    'docs/GettingStarted.md'
    'docs/CLI.md'
    'docs/ManifestAuthoring.md'
    'docs/Diagnostics.md'
    'docs/PublicResultContract.md'
    'docs/PublicPowerShellContract.md'
    'docs/ReleasePackaging.md'
    'core/Wintainium.Core/Wintainium.Core.psd1'
    'core/Wintainium.Core/Wintainium.Core.psm1'
    'schemas/application-manifest.schema.json'
)

foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) {
        throw "Release package validation failed: required asset '$relativePath' is missing."
    }
}

[pscustomobject]@{
    IsValid = $true
    ModuleVersion = [string]$moduleManifest.ModuleVersion
    RootModule = $rootModule
    RequiredAssetCount = $requiredFiles.Count
    RequiredRootDirectoryCount = $expectedRootDirectories.Count
    ExcludedDevelopmentDirectories = @('.git', '.github', 'tests')
    PackageRoot = $root
}
