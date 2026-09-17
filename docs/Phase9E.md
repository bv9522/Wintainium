# Phase 9E — Authoritative State Reconciliation and Persistence

## Objective

Complete the post-install lifecycle boundary that converts reconciliation evidence into Wintainium-managed installed state.

The reconciliation adapter observes application state and returns evidence. Core owns the decision about whether that evidence is authoritative and owns persistence of `InstalledApplicationState`.

## Rules

- Never infer installed version from the selected release.
- Persist only `Installed` or `NotInstalled` evidence that passes the Core reconciliation boundary.
- Preserve an existing authoritative state when reconciliation reports `Unknown`.
- Do not create a new state record from `Unknown` when no prior state exists.
- Reconciliation plugins never persist installed state themselves.
- Reconciliation failure never causes authoritative state persistence.
- OperationId supplied by orchestration is preserved through reconciliation and authoritative-state processing.

## Implementation

`Convert-WintainiumReconciliationEvidenceToInstalledState` converts validated application-scoped evidence into the existing installed-state model without persistence.

`Invoke-WintainiumAuthoritativeStateReconciliation` owns the persistence decision. It returns structured status describing whether state was persisted or an existing state was preserved.

The application update lifecycle now invokes that Core boundary after successful reconciliation. The lifecycle result retains the raw reconciliation evidence and exposes `AuthoritativeStateResult` alongside it.

If authoritative persistence fails, the lifecycle becomes unsuccessful at the Reconciliation boundary rather than reporting a completed update with unrecorded authoritative state.

## Regression coverage

`AuthoritativeStateReconciliation.Tests.ps1` covers installed, not-installed, unknown, empty-state, and OperationId mismatch behavior.

`ApplicationUpdateLifecycleAuthoritativeState.Tests.ps1` covers lifecycle integration, Unknown preservation, authoritative persistence failure, and no-update behavior.
