# GUI Readiness Contract

## Status

Phase 8F — GUI readiness audit: **complete**.

This document defines the boundary a future C#/.NET GUI must consume. Phase 8F does not implement a GUI, select a GUI framework, or expose private engine operations merely to make a prototype convenient.

## Architectural seam

The desktop GUI is a presentation client of the Wintainium engine.

```text
Future GUI / CLI presentation
            |
            v
Stable public/Core operation boundary
            |
            v
Core-owned composition and business rules
            |
            v
Phase 7 lifecycle + stage engines + providers/installers/OS
```

The governing principle is:

> The interface presents the engine; it does not become the engine.

The GUI may request operations, display their structured results, render progress, and present errors or warnings. It must not reproduce Core business rules.

## What the GUI may consume

A GUI may depend on documented public operation inputs and structured results. In particular, it may bind to:

- `OperationId` for operation correlation;
- documented success/validity properties such as `IsSuccessful` and `IsValid`;
- documented `Status` values;
- operation-specific result data;
- structured `Errors` and `Warnings`;
- structured `LogEvents` when exposed by the operation;
- arrays as arrays, including empty collections.

The GUI must make business decisions from documented fields and codes, not from formatted terminal output or human-readable diagnostic wording.

## What the GUI must not consume

The GUI must not depend directly on:

- private Core functions;
- provider or installer implementations;
- provider-specific request construction;
- download or verification helpers;
- orchestration stage executors;
- `StagePlan`, `StageFactory`, or `CancellationContext` construction;
- private state-transition functions;
- internal filesystem/process helpers;
- console formatting or terminal text as an API;
- undocumented object properties solely because they happen to exist.

The GUI must not construct `StagePlan`, `StageFactory`, or `CancellationContext`. Those are internal orchestration concerns owned by Core.

The GUI must not invoke providers or installers directly. It must use the documented Core operation boundary instead.

The GUI must not parse terminal formatting or human-readable diagnostic text as an API.

A GUI implementation must not become a second orchestration engine.

## Stage presentation

The engine owns stage policy and execution order. The GUI may present stage progress when the engine supplies suitable structured progress information, but the GUI does not decide which stages run, when they run, whether they may be skipped, or what constitutes success.

The conceptual lifecycle remains an engine concern:

`ManifestValidation -> ReleaseDiscovery -> UpdateDecision -> Download -> Verification -> InstallerSelection -> Installation -> Reconciliation`

A GUI may show these concepts as progress, but it must not invoke the stages individually to implement an update workflow. The desktop client currently presents activity/cancellation rather than inventing quantitative stage percentages because the public contract does not expose quantitative progress.

## Operation identity and cancellation

`OperationId` is Core-owned. The GUI must preserve it and must not generate a replacement identifier for the same logical operation.

Cancellation is an engine semantic. A GUI may expose a Cancel action, but cancellation must flow through the documented operation boundary and must not be implemented by forcibly terminating arbitrary processes or bypassing stage cleanup.

## Installed-state semantics

The managed installed-state source established by Phase 8E is intentionally narrow. A missing managed record is `Unknown`, not `NotInstalled`.

The GUI must present `Unknown` as unknown/indeterminate and must not silently reinterpret it as an installed or uninstalled condition. It must not manufacture installed state merely to make an update button appear actionable.

## Current update boundary

The current public surface includes the complete Core-owned application update operation: Invoke-WintainiumApplicationUpdate. The earlier internal Get-WintainiumApplicationUpdateDecision composition boundary remains private; the public command owns lifecycle composition and returns the documented projected update result.

The public update operation is now authoritative for the end-to-end update lifecycle. A GUI must invoke it through the documented Core boundary rather than assembling a pseudo-update workflow from private stages or internal requests.

## Presentation independence

The engine returns semantic data. A GUI may transform that data into controls, tables, dialogs, progress indicators, notifications, or other visual representations without changing the underlying operation.

Likewise, a future CLI presentation layer may render the same results for terminal users. Neither presentation layer may alter provider selection, update decisions, acquisition, verification, installer selection, cancellation semantics, or trust requirements.

## Technology boundary

Phase 8F does not require a specific GUI hosting model, transport, process boundary, or interop mechanism. Those choices may be made when GUI implementation begins, provided they preserve this contract.

The important decision now is the semantic seam: presentation clients consume stable Core-owned inputs and results; internal engine wiring remains internal.

## Phase 8F acceptance criteria

The GUI seam is considered ready when:

1. public operations have documented structured input/result contracts;
2. the public module exports only supported user-facing commands;
3. private orchestration and stage dependencies are not required by presentation clients;
4. installed-state `Unknown` semantics are preserved;
5. operation identity and cancellation semantics remain Core-owned;
6. presentation does not depend on console formatting or diagnostic message parsing;
7. the public end-to-end update command is documented and consumable through the stable Core boundary;
8. no GUI code is required to validate this architectural boundary.

## 8F audit result

All eight acceptance criteria remain satisfied by the current engine boundary and contract tests. The supported presentation surface is the six exported public commands, while internal update-decision composition and the Phase 7 lifecycle remain private. The public update result is projected into a stable presentation-neutral contract, and public collection properties remain arrays, including empty collections.

Phase 8F therefore established GUI readiness as an architectural contract, not as a GUI implementation. Phase 10 subsequently completed and exposed the public update operation without weakening that seam. Phase 11 can therefore build the Windows presentation client against the documented four-command boundary without reproducing engine policy or reaching into private orchestration.
