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

**Status: Complete for the current public surface.** `docs/PublicResultContract.md` and `docs/PublicPowerShellContract.md` define the current result and presentation-neutral API boundary, and contract coverage exists for the three currently supported public commands. Their comment-based help documents structured outputs and command responsibilities. The Phase 7 lifecycle remains internal until Core has concrete composition seams for all seven real application-management stages.

**Architecture dependency identified:** the locked Phase 4 update decision requires an installed-application state alongside the manifest and provider result. The current repository has a state-object constructor but no authoritative installed-state retrieval/persistence boundary. Therefore 8B does not manufacture or require caller-supplied installed state merely to make the public update command appear complete. The concrete end-to-end public update command will be exposed only after the real state boundary is established as part of 8E.

### 8C — User documentation and operational guidance

- Write the normal-user guide and CLI reference from actual implemented behavior.
- Document configuration, manifests, plugins, update operations, failures, cancellation, logs, and troubleshooting.
- Keep architecture/developer documentation aligned with public contracts.

**Status: Complete for the current implementation boundary.** `docs/GettingStarted.md`, `docs/CLI.md`, `docs/ManifestAuthoring.md`, and `docs/Diagnostics.md` form the user-facing documentation layer. The guides describe only currently implemented public behavior and explicitly identify the installed-state/update boundary that remains future work. Diagnostics documents structured errors, operation correlation, warnings, log events, and operation-specific troubleshooting. The project charter, architecture overview, module metadata, README, and roadmap have been synchronized with the current engine boundary. Wintainium does not yet expose a persistent end-user configuration command or a public update/install operation, so documentation does not invent those interfaces. Configuration and installed-state persistence remain explicit Phase 8E work.

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

**Status: Complete.** `docs/UpgradePersistence.md` establishes the ownership model, durable-state boundary, installed-state semantics, missing/stale-state rules, upgrade transaction boundary, recovery expectations, and security boundary. Core has an internal JSON persistence boundary for normalized `InstalledApplicationState`: reads return `Unknown` when no record exists, writes validate state before persisting, records are keyed by stable application identity, and writes use a temporary file followed by overwrite-safe replacement.

The Core-owned update-decision composition seam is implemented at the correct internal boundary. `Get-WintainiumApplicationUpdateDecision` accepts the external manifest path, state root, machine architecture, and optional plugin/schema roots; it obtains release discovery, retrieves managed installed state by manifest identity, constructs the internal `UpdateDecisionInput`, and delegates the decision to the locked Phase 4 engine. `Unknown` remains indeterminate and `NotInstalled` remains distinct from an update decision. The full seven-stage lifecycle is not exposed because verification and post-install state reconciliation do not yet have authoritative composition contracts; the final audit confirms that this limitation is intentional and prevents a false or caller-constructed end-to-end API.

The controlled N→N+1 engine replacement path is implemented in `tools/Invoke-WintainiumEngineUpgrade.ps1`. It validates the incoming package before mutation, stages a complete new program tree outside the active root, validates the staged tree independently, switches the program directory only after validation succeeds, preserves durable data located outside the program root, and retains a transaction-specific recovery backup through the activation step. If activation fails, the previous program root is restored. If old-program cleanup fails after a successful switch, the active upgrade remains successful and the recovery location is returned as a warning. The upgrade tool remains outside the distributable runtime package boundary because it is release/installation tooling. Focused coverage verifies successful replacement, obsolete-program removal, durable-state preservation, invalid-package rejection before mutation, missing-root rejection, and package/program boundary protection.

The complete Phase 8 regression checkpoint after the upgrade transaction and its hardening is **377/377 green**.

### 8F — GUI readiness audit and Phase 8 lock

- Verify that a future C#/.NET GUI can consume the public engine boundary without reproducing business rules.
- Confirm the GUI seam is presentation/client code over the PowerShell engine.
- Complete regression, documentation, package, and upgrade validation.
- Lock Phase 8 only when the public contract, release boundary, and upgrade behavior are coherent and tested.

## Version 1.0 — Desktop experience

- C#/.NET GUI over the PowerShell engine
- Plugin manager
- Automatic scheduling and settings
- Release packaging and upgrade path
