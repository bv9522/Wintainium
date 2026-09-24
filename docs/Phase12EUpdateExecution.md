# Phase 12E — Update Execution

## Objective

Connect the desktop application-details surface to the real Core-owned
application update operation without moving lifecycle policy into the GUI.

## Boundary

```
Application Details
        |
        v
WintainiumApplicationUpdateService
        |
        v
WintainiumCoreClient
        |
        v
Invoke-WintainiumApplicationUpdate
        |
        v
Core-owned complete lifecycle
        |
        v
Structured public update result
        |
        v
Desktop update result mapper/model
```

The public PowerShell command remains the execution authority. The desktop
client supplies documented inputs and presents the returned result.

The desktop update result preserves:

- Core-generated OperationId when available;
- IsSuccessful;
- WasCancelled;
- public Status;
- ApplicationId;
- ordered public stage summaries;
- structured Errors, Warnings, and LogEvents;
- the terminal structured Error;
- presentation-layer operation state.

Early Core failures may legitimately have no OperationId. The desktop mapper
therefore does not manufacture one.

## Desktop responsibilities

The desktop client may:

- invoke the public update command;
- supply the documented state, download, and machine-architecture inputs;
- present lifecycle activity and cancellation;
- present structured diagnostics and public stage summaries.

The desktop client must not:

- construct lifecycle stages or orchestration objects;
- select releases or artifacts;
- invoke providers, downloaders, installers, or reconciliation directly;
- infer successful installation from a successful command invocation;
- mutate authoritative installed state.

Post-operation authoritative refresh is deliberately downstream of this batch.

## Current implementation

- Added `WintainiumApplicationUpdateResult` and public stage-summary models.
- Added `WintainiumApplicationUpdateMapper`.
- Added `WintainiumApplicationUpdateService` over the public Core command.
- Added the desktop download-root path under `%LOCALAPPDATA%/Wintainium/Downloads`.
- Added the Run Update action to Application Details.
- Preserved the existing cancellation token boundary.
- Extended the desktop EngineProbe with successful-shape/failure-shape update
  mapping checks, including early failure with a null OperationId.

## Checkpoint

The focused desktop build/EngineProbe checkpoint is pending Brian's local
execution. No green result is claimed in this document until that checkpoint
is observed locally.

Recommended checkpoint:

```powershell
dotnet build .\src\Wintainium.Desktop\Wintainium.Desktop.csproj -c Debug -p:Platform=x64
dotnet run --project .\tools\Wintainium.Desktop.EngineProbe\Wintainium.Desktop.EngineProbe.csproj -- .\core\Wintainium.Core\Wintainium.Core.psd1
```

## Next boundary

Phase 12F/12G will harden result presentation and, critically, reread
authoritative installed state after an update rather than changing the GUI
model to pretend the requested version was installed.
