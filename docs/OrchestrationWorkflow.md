# Wintainium Orchestration Workflow Contract

## Purpose

`Invoke-WintainiumOrchestrationWorkflow` is the Core-owned multi-stage orchestration boundary. It coordinates the authoritative stage plan by repeatedly invoking the locked Phase 7G single-stage coordinator.

The workflow coordinator owns only lifecycle sequencing and propagation. It does not duplicate stage execution, state-transition, cancellation, provider, download, verification, installer, or reconciliation policy.

## Inputs

- `OperationState` — current immutable orchestration state.
- `StagePlan` — authoritative deterministic stage plan.
- `CancellationContext` — Phase 7E cancellation context.
- `StageFactory` — explicit Core-supplied resolver that receives the current stage descriptor, current state, and cancellation context, and returns `StageInput` plus `StageExecutor`.

The workflow does not discover or load arbitrary plugins through `StageFactory`.

## Coordination flow

1. Validate workflow inputs and require a non-empty stage plan.
2. Start from the supplied operation state.
3. For each authoritative stage in plan order, verify that it matches the current state, stop before starting if cancellation is requested, resolve its explicit stage binding, and invoke `Invoke-WintainiumOrchestrationStageOperation` exactly once.
4. On success, replace the local state reference with the newly transitioned state.
5. On ordinary failure, stop immediately and return the failed state.
6. On cancellation, stop immediately without introducing a cancellation state.
7. After the final stage, return the state produced by the final 7G transition.

## Fail-fast behavior

The workflow never skips a failed stage, retries it, or advances past it. A normal stage failure is committed to operation state by the 7G/7D boundary and returned unchanged by the workflow coordinator.

A stage-factory failure occurs before stage execution and therefore cannot be committed as a stage result through 7G. The workflow returns the current state and a structured workflow-level failure.

## Cancellation

Cancellation remains control flow rather than an operation-state status. If cancellation is observed before a stage starts, that stage is not invoked. If 7G reports cancellation during execution, the workflow stops immediately and preserves the current committed state. No `Cancelled` state is invented.

## State and correlation

The workflow never mutates the supplied state in place. It advances its local state reference only with states returned by the 7G coordinator. The parent `OperationId` is preserved across all stages.

## Security and trust boundaries

The workflow does not infer trust from successful prior stages. Download completion does not imply verification, and the workflow does not bypass a future verification boundary. Stage results remain opaque to the workflow coordinator.

The workflow does not construct process commands, invoke arbitrary shell text, select installers, authorize trust, or reconcile installed application state.

## Non-goals

This boundary does not implement provider discovery, update decisions, downloads, artifact verification, trust establishment, installer selection/execution, retry/skip policy, scheduling, multiple-application orchestration, or installed-application state reconciliation.

## Audit checklist

- [x] Uses the authoritative stage plan order.
- [x] Delegates each stage to the locked 7G single-stage coordinator.
- [x] Preserves 7D immutable state-transition ownership.
- [x] Preserves 7E cancellation semantics.
- [x] Fails fast on ordinary stage failure.
- [x] Does not mutate supplied operation state.
- [x] Preserves parent operation correlation.
- [x] Keeps stage input/executor binding explicit.
- [x] Does not bypass verification/trust boundaries.
- [x] Does not add retry, scheduling, update-all, or reconciliation policy.
