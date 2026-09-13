# Wintainium Orchestration Lifecycle Contract

## Purpose

`Invoke-WintainiumOrchestrationLifecycle` is the Core-owned lifecycle boundary for a single orchestration operation. It initializes the operation state once and delegates the complete multi-stage workflow to the locked Phase 7H workflow coordinator.

The lifecycle coordinator owns lifecycle entry and result packaging only. It does not duplicate stage traversal, stage execution, state transition, cancellation, provider, download, verification, installer, or reconciliation policy.

## Inputs

- `Request` — validated Phase 7A orchestration request carrying the parent `OperationId`, normalized manifest path, machine architecture, and download root.
- `StagePlan` — deterministic Phase 7B authoritative stage plan.
- `CancellationContext` — Phase 7E context containing the caller's cancellation token and creation-time cancellation snapshot.
- `StageFactory` — explicit Core-supplied stage binding factory consumed by the 7H workflow.

The lifecycle coordinator requires the request, stage plan, and cancellation context to carry the same parent `OperationId`.

## Coordination flow

1. Validate lifecycle inputs and required request fields.
2. Validate stage-plan structure and operation correlation.
3. Validate cancellation-context structure and operation correlation.
4. Initialize operation state through `New-WintainiumOrchestrationOperationState`.
5. Delegate the initialized state, authoritative plan, cancellation context, and stage factory to `Invoke-WintainiumOrchestrationWorkflow`.
6. Return the workflow's resulting state, stage results, cancellation outcome, and structured error together with the original request and parent operation identifier.

Initialization occurs exactly once. The lifecycle coordinator does not traverse the stage plan itself.

## State and immutability

The supplied request, stage plan, and cancellation context are treated as caller-owned inputs. The lifecycle boundary does not mutate them. Operation state is created as a separate immutable-transition value and subsequently replaced only by the workflow's returned states.

The parent `OperationId` remains the correlation identifier for the lifecycle, operation state, and downstream stage results.

## Cancellation

Cancellation is control flow, not an operation-state status. The lifecycle boundary passes the caller's cancellation context unchanged to the workflow. The workflow observes the live cancellation token between stages and the 7G/7F boundaries observe cancellation during stage execution. No `Cancelled` status is added to operation state.

If cancellation occurs before any stage starts, the initialized state remains `Pending`. If cancellation occurs after one or more stages have completed, the committed state is preserved (normally `Running`) and the lifecycle result reports `WasCancelled = $true`.

## Failure behavior

Invalid lifecycle inputs and state-initialization failures return structured lifecycle-level errors without starting downstream execution. Stage-factory failures are returned by the workflow as structured workflow failures. Ordinary stage execution failures are committed through the locked 7G/7D state-transition boundary and returned as a failed state. The lifecycle coordinator does not retry or skip failures.

## Trust and security boundaries

This boundary does not establish artifact trust, integrity, authenticity, signature validity, or installation approval. A successful download is not treated as verified. The lifecycle coordinator does not construct process commands, invoke arbitrary shell text, select installers, or reconcile installed application state.

The mandatory verification stage remains part of the authoritative Phase 7B plan and is not bypassed by lifecycle coordination.

## Non-goals

This boundary does not implement:

- provider discovery
- release or update decisions
- artifact download
- artifact verification or trust establishment
- installer selection or execution
- retries or stage skipping
- multiple-application/update-all orchestration
- scheduling
- post-install application-state reconciliation

## Audit checklist

- [x] Initializes operation state once through the locked state constructor.
- [x] Delegates complete stage traversal to the locked 7H workflow.
- [x] Does not duplicate 7D state-transition policy.
- [x] Preserves 7E cancellation semantics and the live-token behavior owned by 7H.
- [x] Preserves the parent `OperationId` across lifecycle outputs and downstream state/results.
- [x] Does not mutate caller-owned request, plan, or cancellation context.
- [x] Returns structured lifecycle, workflow, and stage failure information.
- [x] Preserves partial committed state on cancellation or ordinary stage failure.
- [x] Does not bypass the mandatory verification stage or infer trust from acquisition.
- [x] Does not add retry, scheduling, update-all, installer, provider, or reconciliation policy.
