# Wintainium — Phase 9 Handoff

## Complete Update Lifecycle

**Project:** Wintainium
**Phase:** 9
**Status:** Locked
**Branch:** `phase-9-complete-update-lifecycle`
**Final regression:** 428/428 tests passing
**Baseline:** Phase 8F locked at commit `dfe71abfe1a6c0a9cc5d6c00d09b6ef1b1ae11d8` with 382/382 tests passing.

### Product Owner decision

Phase 9 will use a **dedicated, narrow reconciliation/inventory plugin contract** as the source of authoritative post-install evidence.

The reconciler is application-scoped and evidence-producing. It does not become a universal Windows inventory system, does not directly mutate Wintainium managed state, and does not execute arbitrary caller-supplied commands.

### Core objective

Complete this authoritative lifecycle:

Manifest → Application Definition Validation → Provider Discovery → Update Decision → Download → Verification → Installation → Post-Install Reconciliation → Authoritative Managed Installed State

### Initial audit findings

1. **Verification gap:** the repository contains an orchestration Verification stage but no standalone Core verification engine/contract was found during the Phase 8F audit. Downloaded is therefore not yet represented as a distinct trusted/verified artifact result.
2. **Reconciliation gap:** managed-state persistence exists, but there is no mechanism that establishes actual post-install application state. The current orchestration stage plan ends at Installation.
3. **Installer request audit anomaly:** `New-WintainiumInstallerRequest` creates a fresh OperationId. The established orchestration installer path preserves the orchestration OperationId. Phase 9 must classify the helper's call-path status before changing it.

These are Phase 9 gaps/anomalies, not presumed failures of locked earlier phases.

### Execution discipline

Use:

> Inspect → Reason → Implement coherent batch → Test at genuine checkpoint → Commit → Continue → Audit → Lock

Do not make arbitrary micro-changes. Do not expose the public update command until the internal lifecycle is complete and regression-protected.

### Required regression categories

- normal update success
- no update available
- provider failure
- download failure
- verification failure
- installer failure
- reconciliation failure
- cancellation at relevant lifecycle boundaries
- authoritative Installed evidence
- authoritative NotInstalled evidence where supported
- Unknown preservation when evidence is insufficient
- no invented version
- OperationId preservation
- structured failures
- persistence behavior
- full Phase 1–8 regression

### Phase 9 sub-phases

- **9A:** Lifecycle Contract and Evidence Model
- **9B:** Artifact Verification Engine
- **9C:** Reconciliation Contract and Adapter Boundary
- **9D:** Complete Core Composition
- **9E:** Authoritative State Reconciliation and Persistence
- **9F:** Failure, Cancellation, and Boundary Hardening
- **9G:** End-to-End Regression and Public Boundary Preparation

### Completion rule

Phase 9 is locked only when the complete lifecycle is internally executable, every trust/state boundary is explicit, all failure/cancellation semantics are covered, managed state is authoritative rather than inferred, and the full existing regression suite remains green.
