# Wintainium — Phase 9 Plan

## Complete Update Lifecycle

Phase 9 completes the Core-owned update lifecycle without reopening the locked foundations of Phases 1–8 unless a demonstrated incompatibility requires it.

### Architectural basis

The target lifecycle is:

> Manifest → Application Definition Validation → Provider Discovery → Update Decision → Download → Verification → Installation → Post-Install Reconciliation → Authoritative Managed Installed State

The existing architecture already supplies the major domain engines and generic orchestration machinery. Phase 9 supplies the missing Core composition and the two evidence boundaries required to connect them safely.

The governing separation remains:

> Manifest describes. Provider discovers. Core decides. Download obtains. Verification establishes trust. Installer applies. Reconciliation observes. Orchestration coordinates. UX presents.

## Audit findings entering Phase 9

### Confirmed gap 1 — Verification implementation boundary

The repository contains download and installation contracts and an orchestration Verification stage, but no standalone Core verification engine/contract comparable to the other lifecycle engines was found during the Phase 8F audit. Download success is explicitly not equivalent to trust, so Phase 9 must provide the missing verification boundary before installation can proceed.

This is Phase 9 work, not a reason to redesign the locked download or installer phases.

### Confirmed gap 2 — Post-install authoritative reconciliation

Managed installed-state persistence can persist normalized observations, but it cannot establish what is actually installed. The current seven-stage orchestration plan ends at Installation and has no authoritative post-install observation mechanism. Phase 9 therefore introduces a narrow reconciliation contract. The Product Owner selected a dedicated reconciliation/inventory plugin contract as the architectural direction.

The contract must remain application-scoped and evidence-oriented. It must not become universal Windows inventory, arbitrary scripting, or an implicit assumption that installer success establishes installed state.

### Audit anomaly 3 — `New-WintainiumInstallerRequest` OperationId behavior

The helper creates a fresh OperationId, while the established orchestration installer path preserves the orchestration OperationId. Phase 9 will determine whether the helper remains active composition code, is legacy/dead code, or requires a narrowly scoped correction. No Phase 6 reopening is presumed.

## Sub-phases

### Phase 9A — Lifecycle Contract and Evidence Model

Define the complete lifecycle boundary and the contracts required by verification and reconciliation. Establish result shapes, evidence requirements, authoritative-state rules, stage inputs/outputs, OperationId propagation, and structured failure semantics.

**Exit criteria:** contracts are explicit enough that the remaining implementation can be composed without inference or exception-message parsing.

### Phase 9B — Artifact Verification Engine

Implement the missing Core verification capability against the repository's existing artifact metadata and download result model. Verification must be mandatory before installation and must distinguish obtained artifacts from trusted artifacts.

**Exit criteria:** verification succeeds only when the applicable evidence establishes the artifact as acceptable; failures are structured and regression-tested.

### Phase 9C — Reconciliation Contract and Adapter Boundary

Implement the narrow dedicated reconciliation/inventory plugin contract selected by the Product Owner. Define how Core requests application-specific authoritative installed-state evidence and how `Unknown` is preserved when evidence is insufficient.

**Exit criteria:** Core can consume authoritative post-install evidence without turning the reconciler into a universal inventory system or allowing it to mutate managed state directly.

### Phase 9D — Complete Core Composition

Bind the existing manifest validation, provider discovery, update decision, download, verification, installer selection/installation, reconciliation, and managed-state persistence into one Core-owned lifecycle. Extend the internal stage plan as required by the evidence model while preserving Phase 7's generic traversal, cancellation, and lifecycle responsibilities.

The caller must supply application identity/approved inputs, not construct internal orchestration machinery.

**Exit criteria:** a complete single-application update lifecycle exists internally, with one authoritative OperationId and structured lifecycle result/failure behavior.

### Phase 9E — Authoritative State Reconciliation and Persistence

Implement the state transition rules after installation. Successful installation alone must not create an Installed state. Only authoritative reconciliation evidence may establish Installed or NotInstalled. Version must never be invented from the selected release; valid existing state must not be overwritten by unsupported assumptions.

**Exit criteria:** Installed, NotInstalled, and Unknown semantics are deterministic and persisted only from valid authoritative observations.

### Phase 9F — Failure, Cancellation, and Boundary Hardening

Exercise and harden the complete lifecycle across no-update, provider failure, download failure, verification failure, installer failure, reconciliation failure, cancellation, and malformed/unsupported evidence. Confirm cancellation semantics do not imply that an external installer process was terminated unless the installer contract explicitly establishes that behavior.

Resolve the `New-WintainiumInstallerRequest` audit anomaly based on actual call-path usage rather than assumption.

**Exit criteria:** structured failures and cancellation propagate correctly across every lifecycle boundary; no bypass permits installation without verification or authoritative state without reconciliation.

### Phase 9G — End-to-End Regression and Public Boundary Preparation

Build comprehensive regression coverage for the complete lifecycle and run the full Phase 1–8 suite. Verify normal success, no-update, all failure boundaries, cancellation, reconciliation semantics, OperationId preservation, persistence behavior, and locked-phase compatibility.

Only after the internal lifecycle is proven should the public update operation be designed/finalized. The public boundary must consume the Core lifecycle rather than recreate it.

**Exit criteria:** complete lifecycle is regression-protected, prior tests remain green, and the internal engine is ready for a public update command without exposing orchestration internals.

## Phase 9 completion gate

Phase 9 is complete only when all of the following are true:

- The complete lifecycle is Core-owned and internally executable.
- Verification is an explicit mandatory trust boundary.
- Installation cannot proceed from download success alone.
- Post-install reconciliation is explicit and authoritative.
- Installed state is never inferred merely from installer success or selected release metadata.
- `Unknown` remains distinct from `NotInstalled`.
- No version is invented without authoritative evidence.
- OperationId is preserved across the lifecycle.
- Structured failures and cancellation semantics remain intact.
- Managed state persistence records only valid normalized observations.
- The legacy/new installer request helper anomaly is resolved or explicitly classified as unused/dead and covered by that decision.
- Full Phases 1–8 regression remains green.
- The public update boundary is thin and presents the engine rather than becoming the engine.

## What Phase 9 does not reopen

Phase 9 does not redesign the Provider, Update Decision, Download, Installer, generic Orchestration Lifecycle, public result foundations, packaging, or managed-state persistence foundations unless implementation proves a locked contract incapable of supporting the required lifecycle. Any such reopening requires an explicit architectural finding and Product Owner decision.
