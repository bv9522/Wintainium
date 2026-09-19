# Wintainium Getting Started

Wintainium is an engine-first PowerShell project. The supported public surface includes manifest discovery, application validation, release discovery, and the complete application update lifecycle.

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
- `Invoke-WintainiumApplicationUpdate`

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

The bundled application-manifest schema is used automatically. An alternate schema can be supplied explicitly with `-SchemaPath` when working with a controlled development/test layout.

A discovery failure is represented in `Errors`; clients should inspect the stable `Code` property rather than parse `Message` text.

## 2. Validate an application definition

Validate one manifest before release discovery or update execution:

```powershell
$validation = Test-WintainiumApplicationDefinition -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json'
```

Use `IsValid` and structured errors:

```powershell
$validation.IsValid
$validation.Errors | Select-Object Code, Message
```

Application validation resolves the provider, installer, and reconciliation capabilities declared by the manifest. It does **not** perform network access, download an artifact, install an application, reconcile installed state, or manage authoritative installed-application state.

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

Release discovery finds releases through the provider declared by the manifest. It does not decide whether an installed application needs an update, download the selected artifact, verify an artifact, reconcile installation state, or install anything.

## 4. Execute an application update

The complete update lifecycle is available through the public update command:

```powershell
$result = Invoke-WintainiumApplicationUpdate `
    -ManifestPath 'C:\Wintainium\manifests\Example.wintainium.json' `
    -StateRoot 'C:\Wintainium\State' `
    -MachineArchitecture 'x64' `
    -DownloadRoot 'C:\Wintainium\Downloads'
```

The command uses the module's default plugin and schema locations and a default installer timeout of 600000 milliseconds unless those inputs are overridden.

Inspect the public result:

```powershell
$result.Status
$result.IsSuccessful
$result.ApplicationId
$result.Stages | Select-Object Sequence, Name, Status
$result.Errors | Select-Object Code, Message
```

Cancellation is represented explicitly through `WasCancelled = $true` and `Status = 'Cancelled'`. A normal unsuccessful operation reports `Status = 'Failed'`; successful completion reports `Status = 'Completed'`.

The public command does not require callers to construct orchestration plans, cancellation contexts, stage factories, provider requests, download requests, installer requests, reconciliation requests, or individual stage executors.

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

## Public update result

`Invoke-WintainiumApplicationUpdate` returns a stable public projection documented in `docs/PublicApplicationUpdateResult.md`. The result contains only presentation-neutral lifecycle information. Internal orchestration state, stage factories, dependency objects, provider requests, download requests, installer requests, reconciliation requests, and private result objects are intentionally not exposed.

The public result uses:

- `Status = Completed` for successful lifecycle completion;
- `Status = Failed` for unsuccessful non-cancelled execution;
- `Status = Cancelled` when cancellation stops the lifecycle.

`OperationId` is Core-generated. It is null only when execution fails before Core creates the orchestration request.

## What is intentionally private

The public update command is a client-facing boundary over Core-owned lifecycle policy. Clients should not call private functions or construct internal objects such as `StagePlan`, `StageFactory`, `CancellationContext`, provider requests, download requests, installer requests, reconciliation requests, or individual stage executors.

Wintainium-managed installed state is also not a general Windows inventory. If no authoritative managed record exists, the engine preserves that state as `Unknown` rather than manufacturing `NotInstalled`.

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

### Update execution fails

Inspect the structured status and error collection:

```powershell
$result.Status
$result.Errors | Format-Table Code, Message -AutoSize
$result.Stages | Select-Object Sequence, Name, Status, Error
```

Use the stage `Status` and structured `Error.Code` values to identify the lifecycle boundary that failed. Do not parse formatted terminal output.

## Next documentation layers

The detailed public command reference is in `docs/CLI.md`. The update result shape is in `docs/PublicApplicationUpdateResult.md`. Manifest field and policy guidance is in `docs/ManifestAuthoring.md`. Architecture and contributor documentation explain implementation boundaries and are not substitutes for the public CLI contract.
