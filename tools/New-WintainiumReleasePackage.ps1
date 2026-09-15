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
$output = [System.IO.Path]::GetFullPath($OutputRoot)
$moduleManifestPath = Join-Path $repository 'core/Wintainium.Core/Wintainium.Core.psd1'

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

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

$rootFiles = @(
    'ARCHITECTURE.md'
    'CHANGELOG.md'
    'PROJECT.md'
    'README.md'
    'ROADMAP.md'
)

foreach ($relativePath in $rootFiles) {
    Copy-Item -LiteralPath (Join-Path $repository $relativePath) -Destination (Join-Path $packageRoot $relativePath)
}

$directoryBoundaries = @(
    'core'
    'docs'
    'schemas'
    'manifests'
    'plugins'
)

foreach ($directory in $directoryBoundaries) {
    $sourceDirectory = Join-Path $repository $directory
    $targetDirectory = Join-Path $packageRoot $directory
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null

    if (-not (Test-Path -LiteralPath $sourceDirectory -PathType Container)) {
        throw "Release package creation failed: required directory '$directory' is missing."
    }

    Get-ChildItem -LiteralPath $sourceDirectory -File -Recurse | Where-Object {
        $_.Name -ne '.gitkeep'
    } | ForEach-Object {
        $relativePath = $_.FullName.Substring($sourceDirectory.Length).TrimStart('\', '/')
        $destination = Join-Path $targetDirectory $relativePath
        $destinationDirectory = Split-Path -Parent $destination
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $destination
    }
}

$validatorPath = Join-Path $repository 'tools/Test-WintainiumReleasePackage.ps1'
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
