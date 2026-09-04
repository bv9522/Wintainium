# Phase 7D — Orchestration Stage Transition Contract

## Purpose

Phase 7D defines the Core-owned state transition boundary used after an
individual orchestration stage has produced a result. The transition records
the result and either advances to the next planned stage, enters a terminal
failure state, or completes the operation.

`Update-WintainiumOrchestrationOperationState` does not execute a stage. It
only updates orchestration lifecycle state from an already-obtained stage
outcome.

## Input

The transition accepts:

- the current orchestration `State`;
- the authoritative `StagePlan`;
- the completed `StageSequence`;
- the completed `StageName`;
- the stage's structured `StageResult`, which may be null for a failed stage;
- an explicit `Succeeded` boolean interpreted by the orchestration layer.

The state and plan operation identifiers must match. The supplied stage must
match both the current state and the corresponding planned stage.

## Successful Transition

When `Succeeded = $true` and the completed stage is not the final planned stage:

- the stage is appended to `CompletedStages`;
- the stage result is appended to `StageResults`;
- `Status` becomes `Running`;
- `CurrentStageSequence` and `CurrentStageName` advance to the next planned stage;
- `FailedStage` and `Error` remain null.

When the final planned stage succeeds:

- `Status` becomes `Completed`;
- `CurrentStageSequence` and `CurrentStageName` become null;
- all recorded stage results remain preserved.

## Failed Transition

When `Succeeded = $false`:

- the failed stage is recorded in `CompletedStages` as an observed stage outcome;
- its structured result is preserved in `StageResults`;
- `Status` becomes `Failed`;
- the current stage remains the failed stage;
- `FailedStage` identifies the failed stage;
- `Error` preserves the stage result, including a null result when no result object exists.

A failed operation is terminal. It is not automatically retried, skipped, or
advanced by this boundary.

## Validation

The transition rejects malformed state or plan input, operation identifier
mismatches, terminal states, current-stage mismatches, missing planned stages,
and planned sequence/name mismatches. Expected validation failures return
`IsValid = $false`, `State = $null`, and structured errors.

The transition does not mutate the supplied state object; it returns a new
state containing copied lifecycle collections plus the newly recorded result.

## Ownership

The orchestration layer owns lifecycle sequencing and correlation. Stage
engines remain responsible for executing their own work and producing their
own structured results. This boundary does not reinterpret provider, download,
verification, or installer policy.

The `Succeeded` value is an explicit orchestration input; this function does
not guess whether an arbitrary stage result represents success.

## Security Boundary

This transition contains lifecycle metadata and an opaque stage result. It does
not establish artifact authenticity, integrity, signature validity, trust, or
installation authorization. In particular, a successful `Download` transition
cannot by itself produce a successful `Verification` result.

No provider commands, installer executable paths, installer arguments, shell
text, credentials, artifact bytes, or external process execution are introduced
by this boundary.
