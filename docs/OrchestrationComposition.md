# Orchestration Composition Boundary

## Purpose

Phase 7 deliberately separates lifecycle policy from stage implementation. The locked lifecycle accepts a `StageFactory`; the workflow validates and traverses the stage plan, while the factory supplies the executor and input for the current stage.

Phase 8 must preserve that separation while preventing callers from having to understand it.

The intended dependency direction is:

`Public command -> Core composition -> Phase 7 lifecycle -> stage operations -> plugins / OS`

The public command must never become the stage factory, stage planner, provider caller, download request builder, or installer request builder.

## Required Core-owned composition

A complete production composition layer will eventually bind the authoritative seven-stage sequence:

1. ManifestValidation
2. ReleaseDiscovery
3. UpdateDecision
4. Download
5. Verification
6. InstallerSelection
7. Installation

The composition layer owns dependency wiring. The lifecycle owns traversal, transition policy, cancellation boundaries, correlation, and terminal-state handling.

This means a future public update command can accept a small stable request such as a manifest path, architecture, state location, and download root and return one structured operation result. It must not require callers to provide `StagePlan`, `StageFactory`, `CancellationContext`, provider requests, download requests, or installer requests.

## Current repository boundary

Phase 8E now establishes the first caller-independent composition seam at the **update-decision boundary**. `Get-WintainiumApplicationUpdateDecision` accepts the external inputs needed to identify a manifest and state location, invokes the existing release-discovery operation, retrieves the Core-owned installed state, constructs the internal `UpdateDecisionInput`, and delegates the actual decision to the locked Phase 4 operation.

The persisted installed-state record is the current Wintainium-managed state source. It represents the latest state previously established by Wintainium or an explicitly supported state writer; it is not a Windows-wide inventory scan. A missing record remains `Unknown` and therefore produces an indeterminate Phase 4 decision rather than a guessed installation state.

The complete seven-stage lifecycle is **not yet** exposed through this seam. Downloaded-byte verification and post-install state reconciliation still require their concrete composition contracts. The existence of the decision composition must not be mistaken for completion of the end-to-end update pipeline.

Accordingly, Phase 8E does **not** expose a superficial public update command. Internal stage construction remains inside Core until every stage has a real contract and authoritative inputs/outputs.

## Composition invariants

A production Core composition must:

- create the stage plan from the public operation request;
- create and own the operation state and cancellation context;
- bind each stage to its real Core operation;
- preserve the single operation identifier across the lifecycle;
- pass stage outputs forward only through defined contracts;
- prevent provider/installer coupling;
- preserve mandatory verification before installation;
- surface structured operational failures;
- honor cancellation without inventing a `Cancelled` lifecycle status;
- leave presentation and formatting outside the engine;
- avoid retries, skips, update-all behavior, scheduling, or hidden elevation unless separately authorized by a future contract.

The update-decision composition additionally must:

- obtain installed state through the Core-owned state boundary;
- require manifest identity to match installed-state identity;
- preserve `Unknown` rather than guessing `NotInstalled` or `Installed`;
- pass provider releases into Phase 4 only through its existing decision-input contract;
- leave version comparison, eligibility, artifact selection, and update reasoning owned by Phase 4.

## What this seam is not

It is not a general dependency-injection framework, command interpreter, plugin marketplace, persistence database, Windows-wide inventory product, or GUI abstraction.

The goal is deliberately narrow: give Core one authoritative place to assemble the already-defined engine operations so every presentation layer consumes the same business workflow.
