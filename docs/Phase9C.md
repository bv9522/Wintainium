# Phase 9C — Reconciliation Contract and Adapter Boundary

## Status

Phase 9C implementation checkpoint.

## Objective

Establish a dedicated, narrow reconciliation boundary so Wintainium can observe the actual installed state of one managed application without giving reconciliation plugins authority over managed-state persistence or update policy.

## Implemented boundary

The Core adapter `Invoke-WintainiumReconciliationOperation`:

1. accepts an application-scoped reconciliation request and resolved reconciliation plugin;
2. preserves the orchestration-owned `OperationId`;
3. resolves and imports only the descriptor-declared plugin entry point;
4. invokes the plugin's `Invoke-WintainiumReconciliation` operation;
5. requires one structured result;
6. validates result shape and OperationId correlation;
7. validates evidence ownership by `ApplicationId`;
8. accepts only normalized `Installed`, `NotInstalled`, or `Unknown` installation states;
9. preserves structured errors, warnings, and diagnostic events; and
10. returns evidence without granting persistence authority.

The plugin registry and resolver recognize `pluginType = Reconciliation`, contract version `1`, and the `applicationState` capability.

## Evidence rules

Reconciliation is observational. A successful installer operation is not treated as proof of installed state, and a selected release is not treated as proof of installed version.

`Unknown` is a valid result when the source cannot establish installation state. Core must not silently reinterpret `Unknown` as `Installed` or `NotInstalled`.

## Non-goals

Phase 9C does not implement authoritative state persistence, the complete update lifecycle, a universal Windows inventory subsystem, arbitrary shell/process execution, or a public update command.

## Regression checkpoint

`tests/Unit/Reconciliation.Tests.ps1` covers plugin registration/resolution, installed and Unknown evidence, NotInstalled semantics, OperationId and application identity validation, normalized-state validation, structured plugin failure, and the absence of persistence authority.

Phase 9C is complete when the focused reconciliation suite is green and the contract remains compatible with the existing Phase 8E managed-state model.
