# Wintainium Getting Started

Wintainium is currently an engine-first PowerShell project. The supported public surface is intentionally small while the release, installed-state, and end-to-end update boundaries are completed.

## Prerequisites

- Windows PowerShell 7 or later
- A local checkout of Wintainium

Development and test tooling is documented separately in `docs/DEVELOPMENT.md`.

## Import the engine

From the repository root:

```powershell
Import-Module .\core\Wintainium.Core\Wintainium.Core.psd1 -Force
```

Confirm the supported public commands:

```powershell
Get-Command -Module Wintainium.Core
```

The supported user-facing commands are:

- `Get-WintainiumManifest`
- `Test-WintainiumApplicationDefinition`
- `Get-WintainiumApplicationRelease`

These commands return structured objects. They do not print a presentation-specific result that callers must parse.

## 1. Discover manifests

Place application manifests in a local collection directory. Wintainium recognizes the `.wintainium.json` filename convention.

```powershell
$result = Get-WintainiumManifest -Path 'C:\Wintainium\manifests'
```

Inspect the structured result:

```powershell
$result.IsSuccessful
$result.Manifests
$result.Errors
$result.Warnings
$result.LogEvents
```

For recursive discovery:

```powershell
$result = Get-WintainiumManifest -Path 'C:\Wintainium\manifests' -Recurse
```

A discovery failure is represented in `Errors`; clients should inspect the stable `Code` property rather than parse `Message` text.

## 2. Validate an application definition

Validate one manifest before release discovery or future update execution:

```powershell
$validation = Test-WintainiumApplicationDefinition -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json'
```

Use `IsValid` and structured errors:

```powershell
$validation.IsValid
$validation.Errors | Select-Object Code, Message
```

Application validation resolves the provider and installer capabilities declared by the manifest. It does **not** perform network access, download an artifact, install an application, or manage installed-application state.

## 3. Discover releases

Once the application definition is valid, release discovery can be requested:

```powershell
$releaseResult = Get-WintainiumApplicationRelease -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json'
```

Inspect the result without relying on console formatting:

```powershell
$releaseResult.Status
$releaseResult.Releases
$releaseResult.Errors | Select-Object Code, Message
```

Release discovery finds releases through the provider declared by the manifest. It does not decide whether an installed application needs an update, download the selected artifact, or install anything.

## Structured results and automation

The public commands are designed to be consumed directly by PowerShell scripts and future presentation clients.

For example:

```powershell
$result = Get-WintainiumManifest -Path 'C:\Wintainium\manifests'

if (-not $result.IsSuccessful) {
    $result.Errors | ForEach-Object {
        Write-Error "[$($_.Code)] $($_.Message)"
    }
    return
}

$result.Manifests | Select-Object Id, Name
```

For machine-readable transport:

```powershell
$result | ConvertTo-Json -Depth 10
```

Do not depend on property ordering, console formatting, or diagnostic wording. `OperationId` provides the Core-generated correlation identifier for the operation and its log events.

## What is not public yet

The complete install/update lifecycle is deliberately not exposed as a public command yet. The Phase 7 orchestration lifecycle is implemented internally, but a public command must not require callers to construct orchestration plans, cancellation contexts, stage factories, provider requests, download requests, or installer requests.

More importantly, update decision requires authoritative installed-application state. The current implementation does not yet have the persistence/state boundary needed to provide that information. Wintainium therefore does not invent installed state or ask callers to supply it merely to make an end-to-end update command appear complete.

The installed-state and upgrade boundary is planned for Phase 8E. Once the real state boundary and Core-owned stage composition are established, the public orchestration surface can be defined against those contracts.

## Troubleshooting

### The module cannot be imported

Verify that the repository path is correct and that PowerShell 7 or later is being used:

```powershell
$PSVersionTable.PSVersion
Test-Path .\core\Wintainium.Core\Wintainium.Core.psd1
```

### A manifest is not discovered

Check that:

1. The supplied collection path exists and is a directory.
2. The file uses the `.wintainium.json` naming convention.
3. The manifest passes schema and application-definition validation.
4. `Errors` contains no corresponding validation or discovery failure.

### Release discovery fails

Inspect the structured error codes first:

```powershell
$releaseResult.Errors | Format-Table Code, Message -AutoSize
```

A release-discovery result can fail because the application definition is invalid, a declared plugin capability cannot be resolved, or the provider cannot complete discovery. The stable error `Code` is the automation boundary; `Message` is intended for human diagnostics.

## Next documentation layers

The detailed public command reference is in `docs/CLI.md`. Architecture and contributor documentation explain implementation boundaries and are not substitutes for the public CLI contract.
