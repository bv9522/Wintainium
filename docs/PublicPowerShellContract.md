# Public PowerShell Contract

## Status

Phase 8A — Public CLI Contract Audit: **complete**.

This document defines the intended public PowerShell boundary for Wintainium's
engine. It is an API contract decision, not a promise that every operation is
already exposed as a user-facing command.

## Design principle

The PowerShell module is the engine's public presentation-neutral API.
Commands accept explicit inputs, invoke Core-owned business rules, and return
structured results. Human-readable presentation belongs above the engine
boundary and must not change business decisions.

The future C#/.NET GUI is another client of this same boundary. It must not
need to call providers, installers, stage operations, or private orchestration
helpers directly.

## Current exported surface

| Command | Current role | Public status | Phase 8 disposition |
| --- | --- | --- | --- |
| `Get-WintainiumManifest` | Discover and import a local manifest collection | Public | **Retain and refine** |
| `Test-WintainiumApplicationDefinition` | Validate one manifest and resolve required plugins | Public | **Retain and refine** |
| `Get-WintainiumApplicationRelease` | Validate a manifest, resolve its provider, and discover releases | Public | **Retain and refine** |
| `New-WintainiumInstallerRequest` | Transform a completed download result into installer input | Internal helper | **Keep private** |

The module manifest and module loader now export exactly the three intended
user-facing commands. The installer request helper remains available only
inside the loaded Core module scope for internal composition and tests.

## Required public operation boundary

The stable user-facing surface must cover these conceptual operations:

1. **Manifest discovery** — locate/import available application definitions.
2. **Application validation** — determine whether a manifest and its required
   plugins are usable.
3. **Release discovery** — obtain normalized upstream release observations
   through the provider boundary.
4. **Application update lifecycle** — execute the Core-owned orchestration
   lifecycle for an application update.

The fourth operation is the principal missing public entry point. Phase 8B is
establishing the boundary for a purpose-built public wrapper around the locked
Phase 7 lifecycle. The wrapper must not be exposed until Core has a concrete
composition seam capable of constructing the real stage bindings internally.
Callers will not be required to know the internal `StagePlan`, `StageFactory`,
or stage-operation contracts.

## Deliberately non-public

The following remain private implementation details:

- provider registry and provider invocation helpers;
- installer registry, selection, and process helpers;
- manifest import/validation helpers beneath the public validation boundary;
- download and verification stage operations;
- orchestration stage operations, state transitions, workflow coordination,
  lifecycle helpers, and factories;
- log-event construction and other internal plumbing;
- filesystem, process, and plugin-loading helpers.

A function is not public merely because another function calls it or because
it would be technically possible to export it.

## Input rules

Public commands must:

- use explicit named parameters with meaningful PowerShell names;
- validate required inputs at the command boundary;
- avoid accepting arbitrary executable command strings;
- avoid hidden elevation or trust bypasses;
- avoid requiring callers to construct private engine objects;
- preserve caller-owned input objects rather than mutating them;
- use stable, documented defaults only where the default is part of the public
  contract.

Internal implementation objects may remain richer than the public command
input. The public boundary should not expose internal dependency wiring merely
for convenience.

## Result rules

Public engine commands return structured PowerShell objects rather than
formatted text. Results should make success/failure explicit and, where the
operation is correlated, expose the operation identifier.

The public result vocabulary is intentionally centered on:

- `OperationId` where an operation has an operation context;
- `IsSuccessful` or another explicitly documented validity/success property;
- `Status` where a meaningful stable operation status exists;
- operation-specific result data;
- structured `Errors` and `Warnings` where applicable;
- structured diagnostic/log information where that information is part of
  the existing operation contract.

Formatting, tables, colors, progress displays, and other presentation choices
must not become part of Core business logic.

## Error behavior

Expected operational failures should be represented in the documented
structured result contract. Parameter-binding failures and programmer errors
remain normal PowerShell errors where appropriate.

Phase 8B will normalize the distinction between:

- invalid caller input;
- invalid application definition;
- unavailable/incompatible plugin capability;
- provider/discovery failure;
- acquisition failure;
- verification failure;
- installer failure;
- cancellation;
- unexpected internal failure.

The GUI and future automation clients should be able to act on stable error
codes/categories without parsing human-readable messages.

## Pipeline compatibility

Pipeline support will be added only where it improves an actual user workflow
without weakening explicit operation boundaries. Pipeline input is not a goal
by itself, and public commands must not accept ambiguous object shapes merely
to appear pipeline-friendly.

## Machine versus human output

The engine returns data. A CLI presentation layer may render that data for
people or serialize it for automation. No business decision may depend on a
human/machine output switch.

Phase 8B should therefore prefer a consistent structured result model and a
thin presentation wrapper over separate human and machine execution paths.

## GUI seam

A future GUI should be able to perform an update by supplying a stable public
request and receiving a stable structured result. It should not need to know:

`ManifestValidation -> ReleaseDiscovery -> UpdateDecision -> Download ->
Verification -> InstallerSelection -> Installation`

as an implementation sequence.

That sequence remains an engine concern. The GUI may display stage progress
because the engine reports it, but the GUI does not own the stage policy.

## Explicit non-goals for Phase 8A

This audit does not introduce:

- a C#/.NET GUI;
- scheduling;
- update-all orchestration;
- a plugin marketplace;
- persistence/database infrastructure;
- cloud services;
- telemetry;
- a second business-rule implementation;
- arbitrary shell execution;
- a general-purpose command interpreter.

Those remain outside the Phase 8A public-contract decision.
