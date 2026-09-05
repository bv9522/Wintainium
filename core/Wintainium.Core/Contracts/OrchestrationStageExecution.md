# Phase 7F — Orchestration Stage Execution

## Purpose

Phase 7F defines the Core-owned boundary for executing one planned
orchestration stage. The boundary validates the current operation state,
authoritative stage plan, cancellation context, and stage identity before
invoking an explicitly supplied stage executor.

This boundary coordinates stage execution without embedding provider,
download, verification, installer, or post-install policy.

## Input

The boundary accepts:

- the current orchestration `OperationState`;
- the authoritative `StagePlan`;
- the Phase 7E `CancellationContext`;
- the planned `StageSequence` and `StageName`;
- opaque `StageInput` for the selected stage;
- an explicit `StageExecutor` scriptblock implementing the stage boundary.

Operation state must be `Pending` or `Running`. The state, plan, and
cancellation context must share the same valid operation identifier. The
requested stage must match both the current operation state and exactly one
planned stage.

## Execution

Before invoking the executor, the boundary validates the supplied
`CancellationToken`. If cancellation is already requested, execution is not
started and the result reports `WasCancelled = $true`.

For a runnable stage, the executor is invoked with named `StageInput` and
`CancellationToken` parameters. The executor owns the stage-specific work and
may return any stage result object, including `$null`.

An executor exception is converted to a structured orchestration-stage
failure. The boundary does not retry or skip the stage.

## Output

Every result contains:

- `IsSuccessful`;
- `WasCancelled`;
- `OperationId`;
- `StageSequence`;
- `StageName`;
- `Result`;
- `Error` when execution or validation fails.

A successful result means the stage executor completed without throwing. It
does not imply that downstream policy, trust, verification, installation, or
post-install reconciliation has succeeded.

## Ownership

This boundary owns stage-input validation, stage identity checks, cancellation
preflight, executor invocation, and conversion of executor exceptions into
structured failures.

The stage executor owns the semantics of its stage. `Update-WintainiumOrchestrationOperationState`
remains the owner of operation-state transitions; this boundary does not
mutate operation state.

Cancellation remains control flow rather than an operation-state status. Phase
6E remains authoritative for installer process cancellation and process-tree
termination.

## Security and Lifecycle Boundary

The boundary does not infer executables, shell commands, installer arguments,
trust, authenticity, integrity, signatures, or installation approval. It does
not perform post-install application-state reconciliation.

Stage executors are supplied explicitly by Core orchestration. This boundary
does not discover or load arbitrary plugin code and does not grant stage
executors authority outside their existing contracts.
