# Public PowerShell Contract

## Status

Phase 8F — GUI readiness audit: **in progress**.

This document defines the stable public PowerShell boundary for Wintainium's engine. It is an API contract decision, not a promise that every conceptual operation is already exposed as a user-facing command.

## Design principle

The PowerShell module is the engine's public presentation-neutral API. Commands accept explicit inputs, invoke Core-owned business rules, and return structured results. Human-readable presentation belongs above the engine boundary and must not change business decisions.

The future C#/.NET GUI is another client of this same boundary. It must not need to call providers, installers, stage operations, or private orchestration helpers directly.

## Current exported surface

| Command | Current role | Public status | Phase 8 disposition |
| --- | --- | --- | --- |
| `Get-WintainiumManifest` | Discover and import a local manifest collection | Public | **Retain and refine** |
| `Test-WintainiumApplicationDefinition` | Validate one manifest and resolve required plugins | Public | **Retain and refine** |
| `Get-WintainiumApplicationRelease` | Validate a manifest, resolve its provider, and discover releases | Public | **Retain and refine** |
| `New-WintainiumInstallerRequest` | Transform a completed download result into installer input | Internal helper | **Keep private** |

The module manifest and module loader export exactly the three intended user-facing commands. The installer request helper remains available only inside the loaded Core module scope for internal composition and tests.

## Required public operation boundary

The stable user-facing surface is intended to cover these conceptual operations:

1. **Manifest discovery** — locate/import available application definitions.
2. **Application validation** — determine whether a manifest and its required plugins are usable.
3. **Release discovery** — obtain normalized upstream release observations through the provider boundary.
4. **Application update lifecycle** — execute the Core-owned orchestration lifecycle for an application update.

The fourth operation remains intentionally absent from the public surface. Phase 8E established the first Core-owned update-decision composition seam, including authoritative Wintainium-managed installed-state retrieval. The full seven-stage lifecycle still cannot be exposed as a public update command until downloaded-byte verification and post-install state reconciliation have concrete authoritative composition contracts. This document therefore does not turn internal stage dependencies into public parameters or invent a superficial update command.

When the eventual update operation is exposed, callers will not be required to know the internal `StagePlan`, `StageFactory`, `CancellationContext`, provider requests, download requests, installer requests, or stage-operation contracts.

## Installed-state boundary

Phase 8E now provides a narrow Core-managed installed-state persistence boundary. State is keyed by manifest `ApplicationId` and normalized into the existing `InstalledApplicationState` contract. A missing record is `Unknown`, not `NotInstalled`.

The state source is deliberately not a Windows-wide inventory system. It does not infer installation state from arbitrary files or provider identifiers. Future state sources may be added only through an explicit contract that translates their observations into the normalized Core state model.

The public PowerShell surface does not expose the persistence implementation as a general-purpose storage API. Presentation clients consume state only through operations that own an appropriate public result contract.

## Deliberately non-public

The following remain private implementation details:

- provider registry and provider invocation helpers;
- installer registry, selection, and process helpers;
- manifest import/validation helpers beneath the public validation boundary;
- download and verification stage operations;
- orchestration stage operations, state transitions, workflow coordination, lifecycle helpers, and factories;
- log-event construction and other internal plumbing;
- filesystem, process, and plugin-loading helpers;
- managed installed-state persistence helpers and storage details.

A function is not public merely because another function calls it or because it would be technically possible to export it.

## Input rules

Public commands must:

- use explicit named parameters with meaningful PowerShell names;
- validate required inputs at the command boundary;
- avoid accepting arbitrary executable command strings;
- avoid hidden elevation or trust bypasses;
- avoid requiring callers to construct private engine objects;
- preserve caller-owned input objects rather than mutating them;
- use stable, documented defaults only where the default is part of the public contract.

Internal implementation objects may remain richer than the public command input. The public boundary should not expose internal dependency wiring merely for convenience.

## Result rules

Public engine commands return structured PowerShell objects rather than formatted text. Results make success or validity explicit and, where the operation is correlated, expose the Core-generated operation identifier.

The public result vocabulary is intentionally centered on:

- `OperationId` where an operation has an operation context;
- `IsSuccessful` or another explicitly documented validity/success property;
- `Status` where a meaningful stable operation status exists;
- operation-specific result data;
- structured `Errors` and `Warnings` where applicable;
- structured diagnostic/log information where that information is part of the existing operation contract.

Collection-valued result properties are arrays even when empty. Consumers must not depend on property ordering, terminal formatting, or diagnostic message wording for business decisions.

Formatting, tables, colors, progress displays, and other presentation choices must not become part of Core business logic.

## Error behavior

Expected operational failures should be represented in the documented structured result contract. Parameter-binding failures and programmer errors remain normal PowerShell errors where appropriate.

The public boundary recognizes these semantic error categories:

- caller input;
- application definition;
- plugin capability;
- provider/discovery;
- acquisition;
- verification;
- installer;
- cancellation;
- internal/unexpected engine failure.

Individual owning operations remain responsible for their exact documented machine-readable error codes. Clients should branch on documented codes/categories rather than parse human-readable messages.

## Pipeline compatibility

Pipeline support is added only where it improves an actual user workflow without weakening explicit operation boundaries. Pipeline input is not a goal by itself, and public commands must not accept ambiguous object shapes merely to appear pipeline-friendly.

Structured results remain usable with normal PowerShell tooling such as `Select-Object`, `Where-Object`, `ForEach-Object`, and `ConvertTo-Json` without requiring formatted-output parsing.

## Machine versus human output

The engine returns data. A future CLI presentation layer may render that data for people or serialize it for automation. No business decision may depend on a human/machine output switch.

The current public commands therefore expose one semantic result contract rather than separate human and machine execution paths. Any future presentation mode must consume that same result data and must not alter provider selection, update decisions, download behavior, verification requirements, installer selection, cancellation semantics, or other business rules.

## GUI seam

A future GUI should consume this public/Core boundary and must not know the internal stage sequence. It should be able to bind to documented structured results, `OperationId`, stable status values, structured errors/warnings, and operation-specific data without parsing console output.

The GUI must not construct `StagePlan`, `StageFactory`, `CancellationContext`, provider requests, download requests, installer requests, or other private engine objects. It must not invoke providers/installers directly or reproduce Core business rules.

The conceptual lifecycle remains an engine concern:

`ManifestValidation -> ReleaseDiscovery -> UpdateDecision -> Download -> Verification -> InstallerSelection -> Installation`

The GUI may present stage progress when the engine supplies suitable structured progress information, but it does not own stage policy, execution order, skip/retry behavior, or success semantics. See `docs/GUIReadiness.md` for the dedicated presentation-boundary contract.

## Documentation and help

The three currently supported public commands use comment-based help as the authoritative local CLI guidance for their implemented behavior. Each command documents its purpose, public parameters, structured output, and a copy/paste-oriented example.

Examples demonstrate public inputs only. They do not expose private orchestration dependencies or imply that the current public surface can perform an end-to-end update.

## Explicit non-goals for Phase 8

This contract does not introduce:

- a C#/.NET GUI;
- scheduling;
- update-all orchestration;
- a general-purpose persistence or storage API;
- cloud services;
- telemetry;
- a plugin marketplace;
- a second business-rule implementation;
- arbitrary shell execution;
- a general-purpose command interpreter.

Phase 8E's narrow managed installed-state persistence is an established engine boundary, not a public general-purpose storage feature.
