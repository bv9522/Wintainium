# Orchestration Lifecycle Contract

## Purpose

`Invoke-WintainiumOrchestrationLifecycle` is the Core-owned lifecycle envelope for a single orchestration operation. It initializes the authoritative operation state from the stage plan, validates operation correlation, delegates execution to the locked workflow coordinator, and returns one structured lifecycle result.

It does not duplicate stage traversal, stage execution, or state-transition policy.

## Inputs

The lifecycle coordinator accepts:

- the validated Phase 7A orchestration request;
- the authoritative Phase 7B stage plan;
- the Phase 7E cancellation context; and
- an explicit stage factory used by the Phase 7H workflow coordinator.

The request, stage plan, and cancellation context must carry the same operation identifier.

## Lifecycle Sequence

1. validate the required lifecycle inputs and correlation identifiers;
2. initialize the operation state through `New-WintainiumOrchestrationOperationState`;
3. delegate the initialized state and execution context to `Invoke-WintainiumOrchestrationWorkflow`;
4. return the workflow's final state, stage results, cancellation outcome, and structured error together with the original request.

The lifecycle boundary does not create a second state model. The workflow remains responsible for sequential stage coordination, fail-fast behavior, and live cancellation checks.

## Result

The result contains:

- `IsSuccessful` — true only when the delegated workflow completes;
- `WasCancelled` — true when workflow control flow reports cancellation;
- `OperationId` — the parent operation correlation identifier;
- `Request` — the supplied orchestration request;
- `State` — the immutable state produced by the workflow, or null when initialization fails;
- `StageResults` — the ordered stage-operation results returned by the workflow; and
- `Error` — a structured lifecycle/workflow error, or null on success.

## Failure Semantics

Lifecycle validation and state-initialization failures stop before stage execution. Workflow failures and cancellation are returned without retry, skip, or recovery policy being invented by this boundary.

Cancellation remains external control flow. The lifecycle result may report `WasCancelled = true`, but operation state does not gain a `Cancelled` terminal status.

## Correlation and Mutation

`Request.OperationId`, `StagePlan.OperationId`, and `CancellationContext.OperationId` must match. The lifecycle coordinator never mutates the supplied request, stage plan, cancellation context, or caller-owned operation state.

The initial operation state is newly constructed from the authoritative stage plan.

## Trust Boundary

This boundary does not interpret stage results. A successful download stage does not imply verification, trust, safety, or installation approval. Verification remains an explicit stage and may not be bypassed by lifecycle coordination.

## Non-Goals

This boundary does not:

- perform provider discovery;
- make update decisions;
- download artifacts;
- verify artifacts or authorize trust;
- select or execute installers;
- reconcile installed application state;
- retry or skip failed stages;
- schedule operations; or
- coordinate multiple applications/update-all workflows.
