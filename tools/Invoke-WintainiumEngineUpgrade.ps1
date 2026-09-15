[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ProgramRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$package = (Resolve-Path -LiteralPath $PackageRoot -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $package -PathType Container)) {
    throw "Engine upgrade failed: package root '$PackageRoot' is not a directory."
}

$program = [System.IO.Path]::GetFullPath($ProgramRoot)
if (-not (Test-Path -LiteralPath $program -PathType Container)) {
    throw "Engine upgrade failed: existing program root '$ProgramRoot' does not exist."
}

$package = [System.IO.Path]::GetFullPath($package)
if ([string]::Equals($package, $program, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Engine upgrade failed: PackageRoot and ProgramRoot must be different locations.'
}

$programPrefix = $program.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$packagePrefix = $package.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if ($package.StartsWith($programPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
    $program.StartsWith($packagePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Engine upgrade failed: package and program roots must not contain one another.'
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $repositoryRoot 'tools/Test-WintainiumReleasePackage.ps1'
if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
    throw 'Engine upgrade failed: release package validator is unavailable.'
}

$packageValidation = & $validatorPath -PackageRoot $package
if (-not $packageValidation.IsValid) {
    throw 'Engine upgrade failed: incoming package did not pass release validation.'
}

$parent = Split-Path -Parent $program
$leaf = Split-Path -Leaf $program
$transactionId = [guid]::NewGuid().ToString('N')
$staging = Join-Path $parent (".$leaf-upgrade-$transactionId")
$backup = Join-Path $parent (".$leaf-backup-$transactionId")
$stagingCreated = $false
$backupCreated = $false
$switched = $false

try {
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    $stagingCreated = $true

    Get-ChildItem -LiteralPath $package -Force | Sort-Object FullName | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $staging $_.Name) -Recurse -Force
    }

    $stagingValidation = & $validatorPath -PackageRoot $staging
    if (-not $stagingValidation.IsValid) {
        throw 'Engine upgrade failed: staged program files did not pass release validation.'
    }

    if (Test-Path -LiteralPath $backup -PathType Any) {
        throw 'Engine upgrade failed: transaction backup path already exists.'
    }

    Move-Item -LiteralPath $program -Destination $backup
    $backupCreated = $true

    try {
        Move-Item -LiteralPath $staging -Destination $program
        $switched = $true
        $stagingCreated = $false
    }
    catch {
        if (Test-Path -LiteralPath $program -PathType Container) {
            Remove-Item -LiteralPath $program -Recurse -Force -ErrorAction SilentlyContinue
        }
        Move-Item -LiteralPath $backup -Destination $program -ErrorAction Stop
        $backupCreated = $false
        throw
    }

    $cleanupWarning = $null
    try {
        Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction Stop
        $backupCreated = $false
    }
    catch {
        $cleanupWarning = "Previous program files remain in recovery backup '$backup'."
    }

    [pscustomobject][ordered]@{
        IsSuccessful = $true
        ModuleVersion = [string]$stagingValidation.ModuleVersion
        ProgramRoot = $program
        PackageRoot = $package
        RecoveryBackup = if ($backupCreated) { $backup } else { $null }
        Warning = $cleanupWarning
        Validation = $stagingValidation
    }
}
catch {
    if ($stagingCreated -and (Test-Path -LiteralPath $staging -PathType Any)) {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($backupCreated -and -not $switched -and (Test-Path -LiteralPath $backup -PathType Container) -and
        -not (Test-Path -LiteralPath $program -PathType Container)) {
        Move-Item -LiteralPath $backup -Destination $program -ErrorAction SilentlyContinue
    }

    throw
}
