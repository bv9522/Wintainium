# Phase 12F — Authoritative Installed-State Refresh

## Objective

After a desktop update operation returns, reread the application's installed
state through the public Core boundary. The desktop client must present the
state Core reports rather than changing the application model to imply that an
update succeeded.

## Boundary

Application Details
        |
        v
WintainiumApplicationUpdateService
        |
        v
Invoke-WintainiumApplicationUpdate
        |
        v
Structured public update result
        |
        v
Desktop presents update outcome
        |
        v
WintainiumApplicationInstalledStateService
        |
        v
Get-WintainiumApplicationInstalledState
        |
        v
Authoritative installed-state observation
        |
        v
Desktop application model projection

The update result and installed-state observation remain distinct contracts.
The update result describes what the update operation reported. The installed
state describes what Core's authoritative state boundary reports afterward.

## Desktop responsibilities

The desktop client may:

- retain the structured update result for presentation;
- request a fresh installed-state observation after the update operation returns;
- replace its presentation model with the returned installed-state observation;
- present structured refresh errors without inventing state.

The desktop client must not:

- set InstalledVersion to the requested or discovered release version;
- infer installation from IsSuccessful;
- convert a failed or unavailable state read into Installed or NotInstalled;
- invoke reconciliation, installers, providers, or other private lifecycle components directly.

A failed authoritative refresh leaves the existing presentation model
unchanged and surfaces the structured refresh diagnostics.

## Implementation

- Application Details now receives the shared WintainiumApplicationInstalledStateService.
- The update result is retained separately from the application model.
- Every update operation that returns a structured result requests a fresh authoritative installed-state observation.
- Successful state observations are projected through the existing WintainiumApplicationModelMapper.ApplyInstalledState boundary.
- Failed state reads do not modify the application model.
- The desktop EngineProbe now covers successful Unknown-state refresh semantics, no manufactured installed version, and structured refresh failure semantics.

## Checkpoint

Brian should run the focused desktop build and EngineProbe:

powershell
dotnet build .\src\Wintainium.Desktop\Wintainium.Desktop.csproj -c Debug -p:Platform=x64
dotnet run --project .\tools\Wintainium.Desktop.EngineProbe\Wintainium.Desktop.EngineProbe.csproj -- .\core\Wintainium.Core\Wintainium.Core.psd1

A green EngineProbe result establishes the automated refresh boundary; manual
update execution against a real supported application remains a later
integration-hardening checkpoint.

## Next boundary

Phase 12G will complete result/refresh presentation details and close any
remaining gaps between update outcomes, authoritative state, and the desktop
application collection. Phase 12H will perform final integration hardening,
regression, documentation reconciliation, and the Phase 12 lock.
