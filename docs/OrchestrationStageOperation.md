# Wintainium Orchestration Stage Operation Contract

## Purpose

`Invoke-WintainiumOrchestrationStageOperation` is the Core-owned coordination boundary for one orchestration stage. It composes the locked Phase 7F stage-execution boundary with the locked Phase 7D operation-state transition boundary while preserving the Phase 7E cancellation model.

The coordinator owns sequencing of these already-defined boundaries. It does not reimplement their validation or execution mechanics.

## Inputs

- `OperationState` — current immutable orchestration state.
- `StagePlan` — authoritative deterministic stage plan.
- `CancellationContext` — Phase 7E cancellation context.
- `StageSequence` — sequence number of the stage being coordinated.
- `StageName` — authoritative name of the stage being coordinated.
- `StageInput` — opaque input passed to the stage executor.
- `StageExecutor` — Core-supplied stage executor scriptblock.

Required inputs are rejected when absent. Stage identity and cancellation semantics remain owned by `Invoke-WintainiumOrchestrationStage`.

## Coordination flow

1. Execute exactly one stage through `Invoke-WintainiumOrchestrationStage`.
2. If execution succeeds, commit the opaque execution result through `Update-WintainiumOrchestrationOperationState` with `Succeeded = $true`.
3. If execution fails for an ordinary stage error, commit the failure through `Update-WintainiumOrchestrationOperationState` with `Succeeded = $false`. The failed state remains at the current stage and records the failed stage/result according to the 7D contract.
4. If execution is cancelled, return the cancellation outcome without changing operation state. Cancellation is control flow, not a new orchestration status.
5. If a state transition itself is invalid, return a structured coordination failure and do not fabricate a state transition.

## Output

The coordinator returns a single structured object containing:

- `IsSuccessful`
- `OperationId`
- `StageSequence`
- `StageName`
- `Execution`
- `State`
- `Error`

For successful execution, `State` is the new immutable state returned by the transition boundary.

For ordinary execution failure, `IsSuccessful` is false but `State` contains the committed `Failed` state.

For cancellation or coordination/transition failure, `State` remains the supplied state unless a valid failure transition has already been produced.

## Ownership and boundaries

- **Core owns:** stage coordination and propagation of structured outcomes.
- **7F owns:** stage execution, executor invocation, cancellation observation, and stage-level execution errors.
- **7D owns:** immutable orchestration state transitions, including failure recording.
- **7E owns:** cancellation context and the distinction between cancellation control flow and operation status.
- **Providers/installers own:** their specialized discovery or installation mechanisms only; this coordinator does not load arbitrary plugins or grant them orchestration authority.
- **Verification/trust:** this coordinator does not treat download success as verification and does not bypass any future verification boundary.
- **State reconciliation:** this coordinator does not reconcile installed application state.

## Failure policy

A normal stage failure is an orchestration failure and therefore must be committed through the 7D failure transition. This preserves recoverability and makes the operation's terminal failure state explicit.

Cancellation is deliberately different: 7E defines it as external control flow, so a pre-start cancellation leaves the operation state unchanged and does not introduce a `Cancelled` status.

A successful stage whose result cannot be committed is also a coordination failure. The coordinator never advances state speculatively.

## Immutability

The supplied operation state is never mutated in place. State returned by the 7D transition boundary is the only state exposed as the coordinator's updated state.

## Non-goals

This boundary does not:

- execute multiple stages;
- implement a complete end-to-end workflow;
- retry or skip stages;
- perform artifact verification or establish trust;
- select installers;
- install applications;
- reconcile installed application state;
- introduce scheduling or policy automation;
- introduce a separate cancellation terminal status;
- invoke arbitrary shell commands or load arbitrary plugins.

## Audit checklist

- [x] Uses the 7F execution boundary rather than duplicating executor logic.
- [x] Uses the 7D transition boundary for both successful and ordinary failed stages.
- [x] Preserves 7E cancellation semantics without adding `Cancelled` state.
- [x] Preserves the parent `OperationId`.
- [x] Does not mutate supplied operation state.
- [x] Does not bypass verification/trust boundaries.
- [x] Does not perform installer, provider, or state-reconciliation work.
- [x] Returns structured coordination failures rather than throwing stage-policy decisions upward as unstructured exceptions.
