# Reconciliation Result Contract

## Status

Phase 9C contract.

This contract defines the structured result returned by a reconciliation plugin when Core asks it to observe the current state of one Wintainium-managed application.

## Boundary

```text
Application Identity / Manifest / Prior Managed State
                    |
                    v
          Reconciliation Plugin
                    |
                    v
          ReconciliationResult
                    |
                    v
                   Core
                    |
                    v
       InstalledApplicationState
```

The reconciliation plugin observes application state. It does not make update decisions, download artifacts, verify downloaded bytes, install software, or write Wintainium's installed-state persistence file.

## Input

A reconciliation request contains:

| Property | Required | Meaning |
| --- | --- | --- |
| `OperationId` | Yes | Orchestration-owned correlation identifier. |
| `ApplicationId` | Yes | Stable Wintainium application identity. |
| `Manifest` | Yes | Validated application manifest available to Core. |
| `PriorState` | No | Existing managed state, when available. |

The plugin receives application-scoped context only. It is not given authority to enumerate or mutate arbitrary software inventory.

## Result

A reconciliation result contains:

| Property | Required | Meaning |
| --- | --- | --- |
| `OperationId` | Yes | Must equal the request OperationId. |
| `IsSuccessful` | Yes | Whether reconciliation completed without an adapter error. |
| `Status` | Yes | Structured outcome such as `Reconciled` or `Unknown`. |
| `Evidence` | Yes | Zero or one application-scoped observation object. |
| `Errors` | Yes | Structured errors. |
| `Warnings` | Yes | Structured warnings. |
| `LogEvents` | Yes | Correlated diagnostic events. |

`Evidence` is observational data, not persisted managed state. It may contain:

- `ApplicationId`
- `InstallationState` (`Installed`, `NotInstalled`, or `Unknown`)
- `Version`
- `VersionSource`
- `Architecture`
- `Channel`
- `InstallationLocation`
- `EvidenceSource`

`Unknown` is a first-class observation. A plugin must not convert insufficient evidence into `Installed` or `NotInstalled` merely to produce a decisive result.

## Security and Authority

The reconciliation contract is deliberately read-oriented. A reconciliation plugin must not:

- write `installed-state.json` or any other Wintainium managed-state file;
- execute arbitrary instructions supplied by a manifest or request;
- launch an installer or downloaded artifact;
- make update decisions;
- modify the application merely as part of observation;
- act as a Windows-wide inventory subsystem.

Core remains responsible for deciding whether evidence is authoritative and for converting accepted evidence into `InstalledApplicationState` and persistence in Phase 9E.

## Operation Correlation

The reconciliation plugin must preserve the Core-supplied OperationId on its result and any returned log events or warnings that carry an OperationId.

A result with a mismatched OperationId is invalid at the adapter boundary.

## Phase Boundary

Phase 9C establishes the dedicated reconciliation plugin contract and adapter boundary. It does not establish authoritative persistence or complete end-to-end lifecycle composition. Those responsibilities belong to Phase 9E and 9D respectively.
