[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repository = (Resolve-Path -LiteralPath $RepositoryRoot -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $repository -PathType Container)) {
    throw "Release package creation failed: repository root '$RepositoryRoot' is not a directory."
}

$output = [System.IO.Path]::GetFullPath($OutputRoot)
$repositoryWithSeparator = $repository.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$outputWithSeparator = $output.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if ($output -eq $repository -or $output.StartsWith($repositoryWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Release package creation failed: OutputRoot must be outside the repository root.'
}

$moduleManifestPath = Join-Path $repository 'core/Wintainium.Core/Wintainium.Core.psd1'

$requiredRootFiles = @(
    'ARCHITECTURE.md'
    'CHANGELOG.md'
    'PROJECT.md'
    'README.md'
    'ROADMAP.md'
)

$requiredDirectories = @(
    'core'
    'docs'
    'manifests'
    'plugins'
    'schemas'
)

$requiredAssets = @(
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

foreach ($relativePath in $requiredRootFiles + $requiredAssets) {
    if (-not (Test-Path -LiteralPath (Join-Path $repository $relativePath) -PathType Leaf)) {
        throw "Release package creation failed: required source asset '$relativePath' is missing."
    }
}

foreach ($relativePath in $requiredDirectories) {
    if (-not (Test-Path -LiteralPath (Join-Path $repository $relativePath) -PathType Container)) {
        throw "Release package creation failed: required source directory '$relativePath' is missing."
    }
}

$manifest = Import-PowerShellDataFile -LiteralPath $moduleManifestPath
$version = [string]$manifest.ModuleVersion
if ($version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
    throw "Release package creation failed: invalid ModuleVersion '$version'."
}

$packageName = "Wintainium-$version"
$packageRoot = Join-Path $output $packageName
$archivePath = Join-Path $output "$packageName.zip"

if (Test-Path -LiteralPath $packageRoot -PathType Any) {
    throw "Release package creation failed: package directory '$packageRoot' already exists."
}

if (Test-Path -LiteralPath $archivePath -PathType Any) {
    throw "Release package creation failed: archive '$archivePath' already exists."
}

$packageCreated = $false
try {
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    $packageCreated = $true

    foreach ($relativePath in $requiredRootFiles) {
        Copy-Item -LiteralPath (Join-Path $repository $relativePath) -Destination (Join-Path $packageRoot $relativePath)
    }

    foreach ($directory in $requiredDirectories) {
        $sourceDirectory = Join-Path $repository $directory
        $targetDirectory = Join-Path $packageRoot $directory
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null

        Get-ChildItem -LiteralPath $sourceDirectory -File -Recurse | Where-Object {
            $_.Name -ne '.gitkeep'
        } | Sort-Object FullName | ForEach-Object {
            $relativePath = $_.FullName.Substring($sourceDirectory.Length).TrimStart('\', '/')
            $destination = Join-Path $targetDirectory $relativePath
            $destinationDirectory = Split-Path -Parent $destination
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $destination
        }
    }

    $validatorPath = Join-Path $repository 'tools/Test-WintainiumReleasePackage.ps1'
    if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
        throw 'Release package creation failed: release package validator is missing from the repository tooling boundary.'
    }

    $validation = & $validatorPath -PackageRoot $packageRoot
    if (-not $validation.IsValid) {
        throw 'Release package creation failed: assembled package did not pass release validation.'
    }

    Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $archivePath -CompressionLevel Optimal

    [pscustomobject]@{
        IsSuccessful = $true
        ModuleVersion = $version
        PackageRoot = $packageRoot
        ArchivePath = $archivePath
        Validation = $validation
    }
}
catch {
    if (Test-Path -LiteralPath $archivePath -PathType Any) {
        Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
    }

    if ($packageCreated -and (Test-Path -LiteralPath $packageRoot -PathType Any)) {
        Remove-Item -LiteralPath $packageRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    throw
}
