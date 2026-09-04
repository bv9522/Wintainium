# Phase 7B — Orchestration Stage Plan Contract

## Purpose

Phase 7B defines the deterministic lifecycle sequence that a future Core-owned
orchestrator will execute for a single application update operation.

The stage plan is declarative. Creating it performs no manifest validation,
provider discovery, download, artifact verification, installer selection,
installation, or installed-state mutation.

## Required Stage Order

A valid plan contains these required stages in exactly this order:

1. `ManifestValidation`
2. `ReleaseDiscovery`
3. `UpdateDecision`
4. `Download`
5. `Verification`
6. `InstallerSelection`
7. `Installation`

The `Verification` stage is intentionally explicit. A successful download does
not authorize installation, and orchestration must not skip or silently infer
this stage.

## Input

`New-WintainiumOrchestrationStagePlan -OrchestrationRequest <request>` accepts
the successful request produced by `New-WintainiumOrchestrationRequest`.

The request must contain non-empty `OperationId`, `ManifestPath`,
`MachineArchitecture`, and `DownloadRoot` properties. `OperationId` must be a
valid GUID.

## Result

A successful result contains:

- `IsValid = $true`;
- `Plan.OperationId` — the parent orchestration correlation identifier;
- `Plan.ManifestPath`;
- `Plan.MachineArchitecture`;
- `Plan.DownloadRoot`;
- `Plan.Stages` — ordered stage objects containing `Sequence`, `Name`, and
  `Required`;
- `Errors = @()`.

A failed result contains `IsValid = $false`, `Plan = $null`, and structured
errors. Expected validation failures do not throw.

## Ownership

The plan defines sequencing only. Each stage remains owned by its established
Core boundary:

- manifest validation by the Manifest Engine;
- release discovery by the Provider Engine;
- update decisions by Phase 4;
- acquisition by Phase 5;
- verification/trust by its dedicated Core boundary when implemented;
- installer selection and execution by Phase 6.

The stage plan does not duplicate any stage's policy or implementation.

## Security Boundary

The plan contains no executable paths, installer arguments, shell text,
credentials, provider commands, artifact bytes, or trust decisions. It does not
convert downloaded artifacts into trusted artifacts. Installation remains
blocked by the explicit verification stage until a later Core verification
contract establishes the required trust state.
