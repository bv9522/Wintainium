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

**Status: Complete.** The public update execution boundary is implemented and audited. The focused public-contract regression is **58/58 green**.

## Version 1.0 — Desktop experience

- C#/.NET GUI over the PowerShell engine
- Plugin manager
- Automatic scheduling and settings
- Release packaging and upgrade path

### 10G — End-to-End Public Regression

- Exercise the actual public update command through the complete Core-owned lifecycle.
- Cover no-update behavior, verification hard-gate behavior, installer failure, reconciliation failure, authoritative persistence failure, cancellation, Unknown reconciliation evidence, and OperationId preservation.
- Keep lifecycle-layer failure tests as the detailed engine regression while adding public-command entrypoint coverage.
- Run the full Phase 1–10 regression before locking Phase 10.

**Status: Complete and locked.** Public-command end-to-end coverage exercises the successful complete lifecycle and no-update path. Existing lifecycle end-to-end/failure-matrix/authoritative-state coverage supplies the specified failure, cancellation, Unknown-evidence, OperationId, persistence, and verification hard-gate scenarios. The full Phase 1–10 regression is **454/454 green**.

## Phase 11 — C#/.NET GUI Foundation and Desktop Client

**Status: In progress.**

Phase 11 begins the Windows graphical presentation layer over the existing PowerShell engine. The GUI remains a client of the stable Core boundary and does not become a second orchestration engine.

### 11A — Repository, Contract, and Toolchain Audit

- Audit the Phase 10 public/Core boundary and GUI-readiness contract.
- Establish the Windows/.NET development baseline and official WinUI 3 template/toolchain availability.
- Validate the approved in-process Microsoft.PowerShell.SDK hosting approach without changing machine execution policy.
- Confirm structured public PowerShell results cross the C# boundary without terminal parsing.
- Reconcile stale Phase 8 documentation with the completed Phase 10 four-command public surface.

**Status: Complete.** The .NET 10 / PowerShell SDK 7.6.6 probe successfully imported Wintainium.Core, resolved and executed Get-WintainiumManifest, and received a structured result. The WinUI 3 C# template restored and built successfully. Documentation now reflects the four-command public surface and the completed update lifecycle. The production GUI project remains intentionally uncreated until 11B.

### 11B — C#/.NET GUI Project Foundation

- Create the production WinUI 3 desktop project using the established .NET 10 baseline.
- Establish the desktop application's WinUI lifecycle and minimal window boundary.
- Establish the initial C# project dependency model without connecting UI code to Core internals.
- Keep the visual shell intentionally minimal so later phases can make deliberate product and UX decisions.
- Do not finalize launch dimensions, navigation model, title-bar treatment, iconography, tabs, application-list layout, settings layout, or other detailed visual decisions in 11B.

**Status: Complete.** The production desktop project foundation is present under `src/Wintainium.Desktop`, and the project builds successfully with the established .NET 10 / WinUI 3 baseline.

### 11C — Windows Application Shell

- Establish the single-window Wintainium desktop interaction model.
- Use standard Windows title-bar and resizable-window behavior.
- Establish the software collection as the landing view.
- Establish main-window Sort & Filter and Add Software actions.
- Establish Source URL as the primary Add Software input.
- Establish the separate Settings window and the five agreed categories:
  General, Appearance, Updates, Sources, and Advanced.
- Establish the planned Windows 11, Y2K, and Frutiger Aero visual-style boundary
  and System/Light/Dark theme boundary without prematurely implementing the
  complete styling system.
- Reserve application details for the later 11F application-details batch, including the
  per-application Do Not Update policy and editable user Notes surface.
- Keep shell actions presentation-only until the appropriate Core adapter and
  application-model batches.

**Status: In progress.** The initial shell is implemented on branch
phase-11c-application-shell and has passed its first local WinUI build checkpoint. The shell
now includes the functional secondary Settings window and the agreed collection controls;
remaining 11C work is limited to coherent shell hardening and checkpoint validation.
