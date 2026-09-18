# Wintainium Phase 9 — Complete Update Lifecycle

## Objective

Build the missing Core-owned authoritative update lifecycle:

`Manifest → Application Definition Validation → Provider Discovery → Update Decision → Download → Verification → Installation → Post-Install Reconciliation → Authoritative Managed Installed State`

The public update command remains deferred until the complete internal lifecycle is real and regression-tested.

## Phase 9 sub-phases

### 9A — Lifecycle Contract and Evidence Model

- Establish the distinctions between downloaded, verified, installed, reconciled, and authoritative managed state.
- Define trust, state, cancellation, structured-failure, and OperationId boundaries.
- Confirm Core owns managed-state persistence.
- Preserve locked Phase 1–8 boundaries unless a concrete incompatibility is demonstrated.

### 9B — Artifact Verification Engine

- Implement Core-owned downloaded-byte verification.
- Initially support SHA-256 artifact hash evidence.
- Require verification before installer execution.
- Produce structured success/failure results and preserve lifecycle correlation.
- Cover success, mismatch, missing/malformed/unsupported evidence, incomplete download, and non-execution behavior.

### 9C — Reconciliation Contract and Adapter Boundary

- Implement the Product Owner-selected dedicated reconciliation-provider contract.
- Keep reconciliation application-scoped and evidence-producing.
- Do not create a universal Windows inventory API.
- Do not permit arbitrary executable/script instructions or direct state-file mutation.
- Preserve `Unknown` when authoritative evidence cannot establish installed state.

### 9D — Complete Core Composition

- Bind manifest validation, provider discovery, update decision, download, verification, installer selection/execution, and reconciliation through Core-owned composition.
- Add post-install reconciliation to the concrete lifecycle without moving traversal policy into the caller.
- Preserve one orchestration-owned OperationId across compatible stage boundaries.
- Pass outputs forward only through defined contracts.
- Ensure a failed verification cannot reach installation.
- The concrete lifecycle now uses eight stages:
  1. ManifestValidation
  2. ReleaseDiscovery
  3. UpdateDecision
  4. Download
  5. Verification
  6. InstallerSelection
  7. Installation
  8. Reconciliation

### 9E — Authoritative State Reconciliation and Persistence

- Convert valid reconciliation evidence into the existing `InstalledApplicationState` model.
- Persist only authoritative observations through the existing state writer.
- Never invent an installed version from the selected release.
- Never convert `Unknown` into `Installed` or `NotInstalled` by assumption.
- Preserve existing authoritative state when a new observation cannot establish a replacement state.
- Keep authoritative persistence outside the reconciliation provider itself; Core owns the decision to persist.

### 9F — Failure, Cancellation, and Boundary Hardening

- Exercise provider, download, verification, installer, reconciliation, persistence, and cancellation failures through the complete composition.
- Audit OperationId propagation at every request/result boundary.
- Preserve the orchestration-owned OperationId when creating download and installer requests; standalone helper calls may still create their own identifiers.
- Keep structured failure categories intact and avoid exception-message parsing.
- Block downstream lifecycle stages after a failure or cancellation boundary.

### 9G — End-to-End Regression and Public Boundary Preparation

The Phase 9 lifecycle implementation and focused 9G regression set cover:

- normal update through reconciliation
- no-update execution
- provider discovery failure
- download failure
- verification failure
- installer failure boundary
- reconciliation failure boundary
- cancellation boundary
- authoritative persistence failure
- Installed evidence persistence
- NotInstalled evidence persistence
- Unknown evidence preservation
- OperationId identity and propagation
- public Core export boundary
- public command parameter contracts
- public command help and structured output contracts

Representative focused regression files include:

- `ApplicationUpdateLifecycle.Tests.ps1`
- `ApplicationUpdateLifecycleEndToEnd.Tests.ps1`
- `ApplicationUpdateLifecycleFailure.Tests.ps1`
- `ApplicationUpdateLifecycleFailureMatrix.Tests.ps1`
- `ApplicationUpdateLifecycleAuthoritativeState.Tests.ps1`
- `AuthoritativeStateReconciliation.Tests.ps1`
- `OperationIdentityBoundary.Tests.ps1`
- `PublicBoundary.Tests.ps1`
- `PublicCliContract.Tests.ps1`

The final Phase 9 gate is the complete Phase 1–9 Pester regression suite. Phase 9 is not locked until that suite is green.

## Phase 9 audit findings and resolutions

### Confirmed architectural gaps

1. No standalone Core verification engine/contract existed before 9B. Resolved by the Phase 9B verification contract and engine.
2. No post-install reconciliation declaration/mechanism existed in the manifest or Core lifecycle before 9C. Resolved by the dedicated reconciliation contract, manifest schema 1.1 declaration, and lifecycle stage.
3. The original seven-stage plan stopped at Installation. Resolved by the explicit eight-stage lifecycle with Reconciliation.

### Operation identity audit findings

The Phase 7 architecture requires one orchestration-owned OperationId. During the 9B audit, two request helpers were found to create fresh identifiers when called standalone:

- `New-WintainiumInstallerRequest` creates a new OperationId while retaining `DownloadOperationId`.
- `New-WintainiumDownloadRequest` creates a new OperationId when no lifecycle OperationId is supplied.

These helpers were updated to accept and preserve an explicit OperationId. The production Phase 9 lifecycle supplies the orchestration-owned identifier, and focused regression tests verify preservation and rejection of invalid explicit identifiers.

### Public boundary audit

The public Core module intentionally exports only:

- `Get-WintainiumManifest`
- `Test-WintainiumApplicationDefinition`
- `Get-WintainiumApplicationRelease`

The internal `Invoke-WintainiumApplicationUpdateLifecycle` command remains unexported. The public update command is deliberately deferred to a later phase so that its contract can be designed from a locked internal lifecycle rather than becoming the lifecycle itself.

## Architectural non-goals

Phase 9 does not introduce GUI code, C# components, scheduling, update-all behavior, cloud synchronization, telemetry, universal Windows inventory, arbitrary shell/process execution, a database, retry/self-healing policy, rollback, or a persistence redesign.

## Working method

`Inspect → Reason → Implement coherent batch → Test at genuine checkpoint → Commit → Continue → Audit → Lock`

A sub-phase is not considered complete merely because its write-up exists. Its implementation exit criteria and regression coverage must be satisfied before it is locked.
