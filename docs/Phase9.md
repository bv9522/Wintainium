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

- Bind the existing manifest validation, provider discovery, decision, download, verification, installer, and reconciliation operations through Core-owned composition.
- Add post-install reconciliation to the concrete lifecycle without moving traversal policy into the caller.
- Preserve one orchestration-owned OperationId across all compatible stage boundaries.
- Pass outputs forward only through defined contracts.
- Ensure a failed verification cannot reach installation.

### 9E — Authoritative State Reconciliation and Persistence

- Convert valid reconciliation evidence into the existing `InstalledApplicationState` model.
- Persist only authoritative observations through the existing state writer.
- Never invent an installed version from the selected release.
- Never convert `Unknown` into `Installed` or `NotInstalled` by assumption.
- Preserve existing authoritative state when a new observation cannot establish a replacement state.

### 9F — Failure, Cancellation, and Boundary Hardening

- Exercise provider, download, verification, installer, reconciliation, persistence, and cancellation failures through the complete composition.
- Audit OperationId propagation at every request/result boundary.
- Resolve the legacy/new `New-WintainiumInstallerRequest` OperationId behavior according to actual call-path usage.
- Resolve the analogous `New-WintainiumDownloadRequest` fresh-OperationId behavior discovered during the 9B audit; orchestration must remain the single lifecycle owner.
- Keep structured failure categories intact and avoid exception-message parsing.

### 9G — End-to-End Regression and Public Boundary Preparation

- Add complete lifecycle regression coverage for normal update, no-update, provider failure, download failure, verification failure, installer failure, cancellation, reconciliation success/failure, Unknown preservation, Installed/NotInstalled semantics, persistence, and OperationId correlation.
- Run the complete Phase 1–9 regression suite at the final checkpoint.
- Audit the public result shape and only then determine whether the internal lifecycle is mature enough to design the public update command.
- Do not expose `Invoke-WintainiumApplicationUpdate` merely because the internal plumbing exists.

## Phase 9 audit findings

### Confirmed architectural gaps

1. No standalone Core verification engine/contract existed before 9B.
2. No post-install reconciliation declaration/mechanism existed in the manifest or Core lifecycle before 9C.
3. The current seven-stage plan stops at Installation and therefore lacks an explicit reconciliation operation until 9C/9D define its boundary.

### Operation identity audit findings

The Phase 7 architecture requires one orchestration-owned OperationId. During the 9B audit, two additional request helpers were found to create fresh identifiers:

- `New-WintainiumInstallerRequest` creates a new `OperationId` while retaining `DownloadOperationId`.
- `New-WintainiumDownloadRequest` also creates a new `OperationId` while retaining the decision object.

These are not automatically Phase 6/5 defects because the actual Phase 9 composition path has not yet been established. They are Phase 9F audit items: determine active usage and ensure the production lifecycle never substitutes helper-created identifiers for the orchestration-owned identity.

## Architectural non-goals

Phase 9 does not introduce GUI code, C# components, scheduling, update-all behavior, cloud synchronization, telemetry, universal Windows inventory, arbitrary shell/process execution, a database, retry/self-healing policy, rollback, or a persistence redesign.

## Working method

`Inspect → Reason → Implement coherent batch → Test at genuine checkpoint → Commit → Continue → Audit → Lock`

A sub-phase is not considered complete merely because its write-up exists. Its implementation exit criteria and regression coverage must be satisfied before it is locked.
