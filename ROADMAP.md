# Wintainium Roadmap

## Phase 8 — UX, Documentation, Release Preparation & GUI Readiness

Phase 8 bridges the completed engine and the eventual graphical client without moving business rules into presentation code.

### 8A — Public CLI Contract Audit

- Define the stable PowerShell presentation-neutral API boundary.
- Remove low-level implementation helpers from the exported user-facing surface.
- Align module exports and public parameter naming.
- Document the future GUI as another client of the same engine boundary.

**Status: Complete.**

### 8B — CLI UX and public result contract

- Establish the common structured result contract for supported public commands.
- Refine public parameter names, validation, comment-based help, and examples.
- Establish a Core-owned composition seam for the real end-to-end orchestration stage executors before exposing the public update command.
- Expose the purpose-built public orchestration command only after that seam can supply real stage bindings without leaking `StagePlan`, `CancellationContext`, stage factories, provider requests, download requests, or installer requests to callers.
- Standardize stable error categories and machine-readable result data.
- Add appropriate human-readable and machine-readable presentation without putting presentation logic into Core business rules.
- Add contract tests for the supported public command surface.

**Status: Complete for the Phase 8-era public surface.** Phase 10 later extended the public surface with the completed update command after the required Core-owned composition and result-projection boundaries were established.

### 8C — User documentation and operational guidance

- Write the normal-user guide and CLI reference from actual implemented behavior.
- Document configuration, manifests, plugins, update operations, failures, cancellation, logs, and troubleshooting.
- Keep architecture/developer documentation aligned with public contracts.

**Status: Complete for the Phase 8-era implementation boundary.** Phase 10 superseded the earlier documentation's deliberate deferral of public update execution.

### 8D — Release boundary and packaging

- Define deterministic release package contents and layout.
- Establish authoritative version metadata and release validation.
- Validate required Core, schema, plugin, manifest/resource, and documentation assets without bundling development-only material.

**Status: Complete and locked.** `docs/ReleasePackaging.md` defines deterministic release behavior at the file-selection and relative-layout level, the authoritative Core module version source, required assets, excluded development material, independent validation responsibilities, archive limitations, and the Phase 8E upgrade boundary. `tools/Test-WintainiumReleasePackage.ps1` validates the package root boundary, required runtime/documentation assets, Core module version and root module, and the exact supported public export surface. `tools/New-WintainiumReleasePackage.ps1` preflights required source assets before creating output, materializes the documented package boundary as a versioned directory and ZIP archive, omits repository placeholders and development tooling, refuses overwrites, validates the assembled package independently before archiving, and cleans partial output after post-creation failure. Contract coverage exists for validation, assembly, overwrite protection, source preflight, output-boundary protection, and cleanup. The final 8D regression checkpoint is **356/356 green**.

### 8E — Upgrade and persistence contract

- Classify program files, user configuration, application state, logs, caches, manifests, and temporary artifacts from the actual implementation.
- Define safe replacement/preservation behavior for upgrades.
- Establish the authoritative installed-application state boundary needed by update orchestration.
- Validate a supported N→N+1 upgrade path without introducing speculative persistence infrastructure.

**Status: Complete.** `docs/UpgradePersistence.md` establishes the ownership model, durable-state boundary, installed-state semantics, missing/stale-state rules, upgrade transaction boundary, recovery expectations, and security boundary.

### 8F — GUI readiness audit and Phase 8 lock

- Verify that a future C#/.NET GUI can consume the public engine boundary without reproducing business rules.
- Confirm the GUI seam is presentation/client code over the PowerShell engine.
- Complete regression, documentation, package, and upgrade validation.
- Lock Phase 8 only when the public contract, release boundary, and upgrade behavior are coherent and tested.

**Status: Complete and locked.** `docs/GUIReadiness.md` defines the presentation seam, allowed public result consumption, prohibited private dependencies, Core-owned stage policy, OperationId and cancellation semantics, managed installed-state `Unknown` behavior, and the presentation/client boundary. Phase 9 subsequently completed the internal update lifecycle, and Phase 10 exposed that lifecycle through a dedicated public contract.

## Phase 9 — Complete Update Lifecycle

**Status: Complete and locked.**

Phase 9 completed the Core-owned end-to-end lifecycle: manifest validation, release discovery, update decision, download, verification, installer selection, installation, reconciliation, and authoritative managed-state handling. Verification remains Core-owned and mandatory before installation; reconciliation remains an application-scoped evidence boundary; unknown managed state remains unknown rather than being manufactured as installed or not installed.

## Phase 10 — Public Application Update Contract

Phase 10 exposes the completed lifecycle through a stable public PowerShell command without leaking internal orchestration contracts.

### 10A — Public Command Contract

- Establish the public `Invoke-WintainiumApplicationUpdate` parameter boundary.
- Keep OperationId Core-generated.
- Exclude StagePlan, StageFactory, HttpClient, provider requests, download requests, installer requests, reconciliation requests, and other private dependencies from the public surface.
- Preserve documented defaults and parameter validation.
- Verify module exports, help, and package coverage.

**Status: Complete.**

### 10B — Public Result Contract

- Project the internal lifecycle result into a stable presentation-neutral public result.
- Define top-level success, cancellation, status, application identity, stage summaries, diagnostics, and terminal error semantics.
- Keep internal lifecycle state and private result objects out of the public result.
- Document stable collection and status semantics.

**Status: Complete.** `docs/PublicApplicationUpdateResult.md` defines the public result shape and explicitly distinguishes the enumerable `Errors` collection from the terminal `Error` convenience field.

### 10C — Public Update Execution Boundary

- Verify that the public command invokes the complete Core-owned lifecycle rather than requiring caller-created orchestration objects.
- Structure genuine early lifecycle failures at the Core boundary.
- Preserve the documented distinction between parameter-binding failures and operation-result failures.
- Audit public help, CLI documentation, getting-started guidance, README status, result contracts, module exports, and release assets for consistency.

**Status: Implementation complete; awaiting final Pester checkpoint.** The focused Phase 10C boundary/result/CLI/package/GUI coverage is currently **58/58 green**. The final documentation synchronization is complete, and the next checkpoint is a focused Pester run covering the affected public-contract tests.

## Version 1.0 — Desktop experience

- C#/.NET GUI over the PowerShell engine
- Plugin manager
- Automatic scheduling and settings
- Release packaging and upgrade path
