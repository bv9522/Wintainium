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

**Status: Complete and locked.** The 11C shell is implemented and has passed the local WinUI build checkpoint with `dotnet build .\\src\\Wintainium.Desktop\\Wintainium.Desktop.csproj -c Debug -p:Platform=x64`. The primary window, standard Windows behavior, collection landing surface, Sort & Filter controls, Add Software source-URL dialog, and separate Settings window with all five agreed categories are established. Settings has safe close/reopen lifecycle handling. The shell remains presentation-only; Core integration, application models, update policy execution, persistence, and detailed application views remain downstream work. The executable identity is `Wintainium.exe`.

### 11D — Engine Integration Boundary

- Establish the in-process C#/.NET hosting seam for Wintainium.Core using Microsoft.PowerShell.SDK.
- Keep hosted PowerShell execution policy scoped to the runspace; do not modify machine policy.
- Import Wintainium.Core once into the host runspace and serialize command invocations through a single execution boundary.
- Expose only the four documented public Core commands through `WintainiumCoreClient`.
- Preserve structured PowerShell results and error records at the adapter boundary; do not parse terminal output.
- Propagate cancellation through the documented `CancellationToken` parameter for update execution and stop the hosted pipeline when the caller cancels.
- Keep PowerShell SDK types below the adapter-local transport boundary so future application models do not depend directly on PowerShell hosting types.
- Do not wire the WinUI controls to Core yet; downstream 11E–11H batches will consume the adapter through presentation models.

**Status: Complete and locked.** The adapter seam, in-process hosting, public-command allow-list, structured result transport, and cancellation boundary are implemented and validated by the desktop EngineProbe. The adapter remains below the application-facing model layer, and no WinUI control invokes Core directly.

### 11E — Application List Model

- Establish the desktop application model from documented Core manifest results.
- Preserve explicit Core-owned `Unknown` installation and update states rather than inferring missing information.
- Keep installed version, last-updated information, icon data, and update decisions absent until authoritative Core-backed sources exist.
- Establish the application collection loading boundary through the public `Get-WintainiumManifest` command.
- Establish presentation-only Sort & Filter query semantics for the five agreed sort choices and five agreed filters.
- Keep PowerShell SDK types below the application model boundary and preserve structured Core diagnostics.
- Validate collection mapping and query behavior through the desktop EngineProbe without changing the PowerShell engine.

**Status: Complete.** The application model, collection service, presentation-only query boundary, and EngineProbe coverage are implemented. The main window binds ListView and GridView to the same application collection, preserves Core-owned Unknown states, and provides a dedicated List/Grid toggle alongside Sort & Filter and Settings. No GUI manifest root is invented; collection loading remains an explicit application-service boundary until a later authoritative configuration contract supplies its source. Installed-state acquisition, authoritative update status, last-updated data, icon data, application details, persistence, and update execution remain downstream work.
### 11F — Application Details & Release Information

- Open application details from both collection views.
- Present manifest-backed application identity, publisher, homepage, source provider, and installation facts without inventing missing state.
- Preserve the manifest path as application-service metadata so release discovery can address the selected application through the public Core command.
- Establish a C# release-information model and mapper for the documented Get-WintainiumApplicationRelease result.
- Provide a details-window release discovery action through the existing Core adapter.
- Reserve the application-level Do Not Update policy surface without enabling policy behavior before its authoritative persistence/execution contract exists.
- Provide editable Notes with explicit Save and Don't Save behavior while keeping durable persistence downstream.
- Keep update execution, policy enforcement, installed-state acquisition, and durable metadata outside the presentation layer.

**Status: Complete.** The application-details window, release result mapping/service boundary, manifest-path preservation, and EngineProbe coverage are implemented. The local WinUI build and EngineProbe checkpoint are green. The details surface preserves Unknown installation/update state, exposes the reserved Do Not Update policy surface without enforcement, and provides session-scoped Notes Save/Don't Save behavior pending the authoritative persistence boundary. Update execution, policy enforcement, installed-state acquisition, and durable metadata remain outside the presentation layer.
### 11G — Status, Errors, Warnings & Operation State

- Establish a presentation-layer operation-state model for Core-owned structured results.
- Map explicit IsSuccessful and WasCancelled values to presentation state without inferring lifecycle outcomes from formatted text.
- Preserve Core-generated OperationId as the correlation identifier shown to the user-facing layer.
- Preserve structured Errors and Warnings diagnostics with machine-readable codes and optional paths/messages.
- Surface operation state and structured diagnostics in application details without exposing PowerShell transport types or private lifecycle objects.
- Keep lifecycle execution, retry policy, cancellation ownership, and terminal error semantics in Core.

**Status: Complete.** The presentation-layer operation-state model/mapper, application collection and release-result state mapping, structured diagnostic preservation, application-details status surface, and EngineProbe coverage are implemented. The local WinUI build and EngineProbe checkpoint are green. Terminal operation outcomes remain Core-owned; the desktop layer presents explicit success/failure/cancellation state, OperationId, and structured diagnostics without parsing formatted output or exposing private lifecycle objects.
### 11H — Progress & Cancellation

- Present Core-owned operation progress/activity without moving lifecycle decisions into the desktop client.
- Provide a user-visible cancellation action for cancellable operations.
- Propagate cancellation through the existing C# adapter CancellationToken boundary.
- Keep cancellation ownership and terminal outcome determination in Core.
- Ensure operation controls return to an idle state after completion, failure, or cancellation.
- Avoid inventing progress percentages when the public Core contract does not provide quantitative progress.
- Exercise cancellation and operation-control behavior through the desktop checkpoint without changing the PowerShell engine.

**Status: Complete.** Application release discovery now has a Core-backed cancellation token, a user-visible activity indicator, a Cancel action, and safe window-close cancellation cleanup. Operation controls return to idle after completion, failure, or cancellation, and the desktop layer does not invent quantitative progress that the public Core contract does not provide. The local WinUI build and EngineProbe checkpoint are green.

### 11J — GUI Testing & Integration Hardening

- Establish focused desktop-side coverage for application collection, details/release discovery, settings, operation state, and cancellation boundaries.
- Keep EngineProbe coverage for the public Core adapter contract and structured result mapping.
- Verify window lifecycle behavior for the main window, Settings, and application Details windows.
- Verify presentation behavior does not infer engine-owned state or parse formatted output.
- Exercise failure, cancellation, and structured diagnostic presentation without changing Core lifecycle semantics.
- Keep PowerShell/Pester regression authoritative; run Pester only if this batch requires Core/PowerShell changes.
- Finish with a clean local WinUI build and desktop checkpoint before locking 11J.

**Status: Complete and locked.** The desktop EngineProbe covers the application collection/model/query boundary, release mapping, explicit operation-state mapping, structured diagnostics, session-scoped settings, and the cancellation token boundary. `docs/DesktopTesting.md` defines the WinUI interaction and window-lifecycle checkpoint. The local WinUI build and full desktop interaction checkpoint are green. No Core/PowerShell changes were required, so the authoritative Pester regression remains unchanged.

### 11K — GUI Foundation Audit & Phase 11 Lock

- Perform the final architectural audit of the completed C#/.NET/WinUI desktop foundation.
- Verify that Wintainium.Core remains authoritative for discovery, update decisions, lifecycle execution, provider/installer behavior, verification, reconciliation, cancellation semantics, and terminal operation outcomes.
- Verify that the desktop client depends only on documented public Core commands and structured results, without provider/installer coupling, console parsing, undocumented properties, or duplicated engine state authority.
- Verify structured diagnostics and OperationId preservation, explicit cancellation handling, and Unknown installed-state semantics.
- Reconcile GUI, configuration, testing, project, roadmap, changelog, and AI-context documentation with the implementation.
- Run the complete Phase 1–10 PowerShell/Pester regression and the final desktop build/EngineProbe checkpoint before declaring Phase 11 locked.

**Status: Complete and locked.** The final GUI foundation architectural audit is complete. The C#/.NET/WinUI desktop client uses the documented four-command Core boundary; Core remains authoritative for discovery, update decisions, lifecycle execution, provider/installer behavior, verification, reconciliation, cancellation semantics, and terminal outcomes. No provider/installer coupling, console parsing, undocumented contract dependency, duplicated engine authority, or unstructured diagnostic dependency was identified. GUI, configuration, testing, project, roadmap, changelog, and AI-context documentation are reconciled with the implementation. The final desktop checkpoint is green, and the complete Phase 1–10 PowerShell/Pester regression is **454/454 green**. Phase 11 is complete and locked.
### 11I — Settings & Configuration Foundation

- Establish the desktop configuration ownership boundary without inventing a GUI manifest root or duplicating Core persistence.
- Establish a desktop-owned settings model/service for presentation-specific preferences.
- Preserve the agreed Settings categories: General, Appearance, Updates, Sources, and Advanced.
- Establish Theme (System/Light/Dark) and Visual Style (Windows 11/Y2K/Frutiger Aero) as the first desktop-owned settings.
- Keep the initial settings service session-scoped until durable configuration ownership, storage location, upgrade behavior, and failure semantics are explicitly defined.
- Keep Wintainium self-update information separate from managed-application update state.
- Do not introduce scheduling, provider configuration, application policy persistence, notes persistence, or other engine-owned state without an authoritative contract.

**Status: Complete.** The desktop settings model/service, application-scoped ownership, Appearance controls, and configuration-boundary documentation are implemented. The local WinUI build and desktop checkpoint are green. Durable persistence remains intentionally deferred pending an authoritative storage contract.


## Phase 12 — GUI Integration and Source Onboarding

**Status: In progress.**

Phase 12 connects the desktop shell to real Wintainium operations and extends Add Software from a presentation-only source URL field into a Core-owned source-onboarding workflow. The user supplies an official source/release/download URL; Wintainium resolves supported sources into normalized application/source facts without requiring user-authored JSON.

### 12.1 — Source Onboarding Contract
- Define the normalized source URL input and structured source-resolution result.
- Preserve OperationId, structured diagnostics, cancellation, and exactly-one-result semantics.
- Keep source resolution separate from release discovery and update execution.

**Status: Complete.** docs/SourceResolutionContract.md defines the additive source-resolution boundary.

### 12.2 — Source Resolution Architecture
- Add source resolution as an optional provider capability without breaking Provider Contract v1.
- Keep source-specific interpretation behind the provider boundary.
- Explicitly support deterministic unsupported/ambiguous/authentication/interactive outcomes.
- Do not authorize arbitrary web scraping.

**Status: Architecture established.** docs/Phase12BSourceResolution.md and docs/ArchitectureDecision-SourceResolution.md define the boundary and constraints.

### 12.3 — GitHub Source Resolution
- Resolve GitHub repository, releases, and release-tag URLs into normalized source facts.
- Establish GitHub as the first source-resolution vertical slice.
- Preserve existing GitHub release/artifact discovery behavior.

**Status: Complete.** Focused GitHub source-resolution coverage is 8/8 green.

### 12.4 — Normalized Application Model
- Construct a valid application definition from resolved source facts.
- Keep application identity, provider settings, installer capability, release policy, and artifact policy authoritative and Core-owned.

**Status: Complete.** `New-WintainiumApplicationDefinitionFromSource` establishes the normalization boundary and focused Pester validation is **5/5 green**.

### 12.5 — Official Download Page Resolution
- Establish generalized structured official download-page resolution.
- Validate against sources such as 7-Zip and VLC without adding vendor-specific branches to Core.

**Status: Complete.** The constrained official-download-page provider resolves supported HTML identity metadata into normalized source facts without returning artifacts or executing page content. Focused coverage is **9/9 green**.

### 12.6 — Environment Model
- Establish a Core-owned environment snapshot for operating-system and architecture facts.
- Distinguish machine architecture from current process architecture.
- Provide deterministic overrides for tests and trusted future integration inputs.
- Keep environment discovery separate from installed application state and decision logic.

**Status: Complete.** `Get-WintainiumEnvironment` and `docs/EnvironmentModel.md` establish the environment boundary. Focused coverage is **4/4 green**.

### 12.7 — Artifact Selection Integration
- Route artifact eligibility and deterministic artifact selection through the Core-owned environment snapshot.
- Preserve existing manifest format/architecture policy and deterministic ranking behavior.
- Retain the legacy machine-architecture parameter as a compatibility seam while making the environment snapshot authoritative downstream.
- Cover environment precedence at update decision, target resolution, artifact selection, and artifact eligibility boundaries.

**Status: Complete.** Environment-aware artifact selection is integrated through update decisions, target resolution, artifact selection, and eligibility. Focused checkpoints are **6/6, 9/9, and 11/11 green**.

### 12.8 — Persistence
- Persist onboarded application definitions under the authoritative manifest collection boundary.
- Validate application definitions against the existing manifest schema before deriving destination paths.
- Use atomic replacement semantics by application identity.
- Keep installed application observations authoritative in `installed-state.json`; do not create a competing state store.
- Keep desktop settings/notes session-scoped until a separate durable desktop-configuration contract exists.

**Status: Complete.** `Set-WintainiumApplicationDefinition` persists schema-validated application definitions using the existing `.wintainium.json` manifest convention with atomic replacement semantics. Focused persistence coverage is **6/6 green**.

### 12.9 — Desktop Integration
- Connect the desktop collection to the authoritative Core manifest boundary.
- Establish the fixed desktop application collection root under the user's local application data.
- Connect Add Software to Core-owned source onboarding and application-definition persistence.
- Preserve Core-owned policy, source resolution, normalization, validation, and persistence authority.
- Present structured Core diagnostics without terminal parsing or GUI-side lifecycle fallback.
- Validate startup collection loading, onboarding flow, Settings lifecycle, Sort & Filter, List/Grid presentation, and expected policy-unavailable behavior against the current plugin set.

**Status: Complete.** The desktop collection and onboarding flow are integrated through the documented Core boundary. The collection root is `%LOCALAPPDATA%/Wintainium/Applications`; Core remains authoritative for manifest persistence and onboarding policy. The local WinUI build checkpoint is green, and the complete manual desktop runtime checkpoint passed: startup collection loading, Add Software dialog, Settings lifecycle, Sort & Filter/List-Grid controls, Core onboarding/error presentation, and post-error application usability. No Core/PowerShell changes were required for this batch, so the existing Pester baseline remains authoritative.

### 12.10 — Real-World Source Validation
**Status: Complete and locked.** 12.10A established the live-validation boundary and 12.10B completed and locked the live source-validation checkpoint.

12.10 was split into focused validation batches so Phase 12B is not conflated with the later Phase 12 integration work.

#### 12.10A — Real-World Validation Plan
**Status: Complete.** Define the live-source validation boundary, distinguish deterministic GitHub URL normalization from network-backed official-page resolution, and keep lifecycle execution outside the checkpoint.

#### 12.10B — Live Source Validation
**Status: Complete and locked.** `docs/Phase12BRealWorldValidation.md` and `tests/Integration/Phase12B-RealWorldSourceValidation.Tests.ps1` establish the live checkpoint for GitHub repository/release URLs and the 7-Zip/VLC official download pages. The final live checkpoint is **4/4 green**. The lock covers source-resolution validation only and does not extend to release discovery, artifact selection, downloading, verification, installation, reconciliation, or end-to-end onboarding.

### 12.11 — Unsupported/Interactive Source Handling
- Validate deterministic propagation of unsupported, ambiguous, unavailable, authentication-required, interactive, and invalid source-resolution outcomes.
- Preserve the no-state/no-persistence boundary for all source-resolution failures.
- Map structured Core outcomes to desktop UX without implementing provider logic in the GUI.
- Provide an OS-level Open Source action only for authentication-required and interactive-resolution outcomes.
- Keep the deterministic source-resolution failure provider test-only and outside the production plugin set.

**Status: Complete.** `docs/Phase12UnsupportedInteractiveSourceHandling.md` records the boundary and validation. The focused Core regression is **14/14 green**, and the Debug desktop manual checkpoint passed all **6/6** source-resolution failure scenarios. Final phase locking remains in 12.12.

### 12.12 — Integration, Regression, Audit & Lock
- Reconcile source-onboarding architecture, contracts, desktop integration, roadmap, changelog, and test documentation.
- Run the focused Core onboarding regression and live source-resolution integration regression.
- Re-run the x64 desktop build and the six-scenario unsupported/interactive source UX checkpoint.
- Verify the test-only source-resolution failure fixture is excluded from the production plugin set.
- Lock Phase 12B only after observed local checkpoints pass.

**Status: In progress.** `docs/Phase12BIntegrationAudit.md` defines the final checkpoint and lock boundary.
