# Orchestration Composition Boundary

## Purpose

Phase 7 deliberately separates lifecycle policy from stage implementation. The locked lifecycle accepts a `StageFactory`; the workflow validates and traverses the stage plan, while the factory supplies the executor and input for the current stage.

Phase 8B must preserve that separation while preventing callers from having to understand it.

The intended dependency direction is:

`Public command -> Core composition -> Phase 7 lifecycle -> stage operations -> plugins / OS`

The public command must never become the stage factory, stage planner, provider caller, download request builder, or installer request builder.

## Required Core-owned composition

A production composition layer will eventually bind the authoritative seven-stage sequence:

1. ManifestValidation
2. ReleaseDiscovery
3. UpdateDecision
4. Download
5. Verification
6. InstallerSelection
7. Installation

The composition layer owns dependency wiring. The lifecycle owns traversal, transition policy, cancellation boundaries, correlation, and terminal-state handling.

This means a future public update command can accept a small stable request such as a manifest path, architecture, and download root and return one structured operation result. It must not require callers to provide `StagePlan`, `StageFactory`, `CancellationContext`, provider requests, download requests, or installer requests.

## Current repository boundary

The first six/seven conceptual stages do not yet form a complete caller-independent composition because update decision requires authoritative installed-application state.

The current Core contains a constructor for an installed application state object, but that constructor does not discover or persist the state. Treating an invented default state as authoritative would change update semantics and could cause an installation decision that does not reflect the machine.

Accordingly, Phase 8B does **not** expose a superficial end-to-end update command. It also does not make installed state a public caller responsibility merely to satisfy the shape of the Phase 7 lifecycle.

The authoritative installed-state boundary is part of the Phase 8E persistence/upgrade contract and must be established before the public update lifecycle is considered complete.

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

## What this seam is not

It is not a general dependency-injection framework, command interpreter, plugin marketplace, persistence database, or GUI abstraction.

The goal is deliberately narrow: give Core one authoritative place to assemble the already-defined engine operations so every presentation layer consumes the same business workflow.
