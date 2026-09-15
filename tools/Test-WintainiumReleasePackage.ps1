[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $PackageRoot -ErrorAction Stop).Path
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
if (@($moduleManifest.FunctionsToExport) -cne $expectedExports) {
    throw 'Release package validation failed: exported public command surface does not match the supported contract.'
}

$requiredFiles = @(
    'README.md'
    'PROJECT.md'
    'ARCHITECTURE.md'
    'ROADMAP.md'
    'CHANGELOG.md'
    'core/Wintainium.Core/Wintainium.Core.psd1'
    'core/Wintainium.Core/Wintainium.Core.psm1'
    'schemas/application-manifest.schema.json'
)

foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) {
        throw "Release package validation failed: required asset '$relativePath' is missing."
    }
}

foreach ($excludedDirectory in @('.git', '.github', 'tests')) {
    if (Test-Path -LiteralPath (Join-Path $root $excludedDirectory)) {
        throw "Release package validation failed: development directory '$excludedDirectory' is present."
    }
}

[pscustomobject]@{
    IsValid = $true
    ModuleVersion = [string]$moduleManifest.ModuleVersion
    RootModule = $rootModule
    RequiredAssetCount = $requiredFiles.Count
    ExcludedDevelopmentDirectories = @('.git', '.github', 'tests')
    PackageRoot = $root
}
