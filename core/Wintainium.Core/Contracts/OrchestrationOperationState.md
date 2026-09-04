# Phase 7C — Orchestration Operation State Contract

## Purpose

Phase 7C defines the Core-owned state initialized from a valid orchestration
stage plan. The state provides a deterministic correlation context for a future
orchestrator without executing any lifecycle stage.

## Initialization

`New-WintainiumOrchestrationOperationState -StagePlan <plan>` accepts a valid
stage plan produced by `New-WintainiumOrchestrationStagePlan`.

The operation state preserves the parent `OperationId` from the plan. It does
not create a second operation identifier.

The initial state is:

- `Status = Pending`;
- `CurrentStageSequence` set to the first planned stage;
- `CurrentStageName` set to the first planned stage name;
- `CompletedStages = @()`;
- `StageResults = @()`;
- `FailedStage = $null`;
- `Error = $null`.

## Validation

The state initializer validates the structural shape needed for deterministic
state tracking. The plan must contain a valid operation identifier and at least
one stage. Each stage must contain `Sequence`, `Name`, and `Required`, and stage
sequences must begin at 1 and increase contiguously.

Expected validation failures return `IsValid = $false`, `State = $null`, and
structured errors rather than throwing.

## Boundary

Creating operation state does not:

- validate the manifest;
- invoke providers;
- make an update decision;
- download artifacts;
- verify artifact integrity, authenticity, signatures, or trust;
- select or invoke an installer;
- mutate installed application state;
- execute external processes.

Stage results are reserved for later orchestration execution. The initializer
must not fabricate successful stage outcomes.

## Ownership

The orchestration layer owns correlation and lifecycle state. Individual stage
engines remain responsible for their own policies and structured results. A
future executor will advance this state only after an actual stage result has
been obtained.

## Security Boundary

The state object contains lifecycle metadata only. It does not establish trust
for downloaded artifacts and does not authorize installation. In particular,
`Download` completion must not be represented as a successful `Verification`
result merely because the orchestration state has been initialized.
