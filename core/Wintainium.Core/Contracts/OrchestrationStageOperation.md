# Orchestration Stage Operation Contract

## Purpose

`Invoke-WintainiumOrchestrationStageOperation` is the Core-owned coordination boundary for completing one planned orchestration stage and committing its successful result to the operation state.

It composes the already-locked Phase 7D stage-transition boundary with the already-locked Phase 7F stage-execution boundary. It does not replace either boundary or duplicate their policy.

## Inputs

The operation accepts:

- the current orchestration operation state;
- the authoritative stage plan;
- the orchestration cancellation context;
- the current stage sequence and name;
- opaque stage input; and
- an explicit stage executor scriptblock.

The requested stage must be the current state stage and must exist with the same identity in the authoritative plan. Operation identifiers must remain consistent across state, plan, and cancellation context.

## Coordination Sequence

For a single stage:

1. invoke `Invoke-WintainiumOrchestrationStage` with the supplied execution context;
2. if stage execution does not succeed, return a structured coordination failure and preserve the supplied state unchanged;
3. when execution succeeds, pass its opaque `Result` to `Update-WintainiumOrchestrationOperationState` with `Succeeded = $true`;
4. return the newly transitioned state and the execution result.

A successful execution therefore becomes a completed stage only through the existing state-transition boundary.

## Failure Semantics

Execution failure is terminal for this coordination call, but it does not mutate the operation state or invent a new operation-state status. The returned state remains the supplied state.

If the state transition unexpectedly rejects a successful execution, the operation returns a structured coordination failure and does not substitute a locally constructed state.

Cancellation before stage execution is reported through the stage execution result. The coordinator does not add a `Cancelled` operation-state status; cancellation remains external control flow under the Phase 7E contract.

## Boundary Ownership

- Phase 7D owns authoritative operation-state transitions.
- Phase 7E owns cancellation context propagation.
- Phase 7F owns single-stage executor invocation and executor exception/cancellation handling.
- Phase 7G owns composition of those boundaries for one stage.

The coordinator does not perform provider discovery, download, verification, installer selection, installer invocation, post-install reconciliation, retry policy, scheduling, or trust authorization.

## Security and Trust Boundary

Opaque stage results remain opaque. A successful stage execution does not by itself establish artifact authenticity, integrity, signature validity, trust, safety, or installation approval.

In particular, this boundary must not interpret a successful download as successful verification or infer trust from filenames, paths, or stage names.

## Mutation Rule

The supplied operation state is never mutated in place. Successful state advancement is delegated to the existing transition function, which returns a new state.

## Non-Goals

This boundary does not:

- execute arbitrary shell text;
- discover or load installer/provider plugins;
- construct process commands;
- decide update eligibility;
- establish artifact trust;
- add retry or skip behavior;
- reconcile installed application state; or
- define multi-application/update-all orchestration.
