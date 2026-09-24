# Changelog

## Unreleased — Phase 12F Authoritative Refresh

### Added

- Phase 12F authoritative installed-state refresh after desktop update execution.
- Desktop EngineProbe coverage for Unknown-state refresh, no manufactured installed version, and structured refresh failure.

### Changed

- Application Details now retains the structured update result separately and rereads authoritative installed state through the public Core boundary instead of manufacturing successful installation state.

### Phase 12E — Update Execution

### Added

- Phase 12D release-discovery completion documentation and public release checkpoint (**6/6 green** as observed locally).
- Phase 12E desktop application-update result model, mapper, service, download-root boundary, and Application Details Run Update action.
- Extended the desktop EngineProbe with update-result mapping coverage, including early Core failure with a null OperationId.



- Added the WinUI application-details surface over the 11E application model.
- Added manifest-path preservation and a C# release-information mapping/service boundary over the public `Get-WintainiumApplicationRelease` command.
- Added release discovery presentation without moving update decisions into the desktop client.
- Added the reserved Do Not Update policy surface and session-scoped Notes Save/Don't Save behavior.
- Added EngineProbe coverage for structured application release mapping.


All notable changes will be documented in this file.

This project intends to follow the principles of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and semantic
versioning once releases begin.

## [Unreleased]

### Added

- Phase 12.10B live source validation covering GitHub repository/release URLs and 7-Zip/VLC official download pages; final checkpoint **4/4 green**.
- Initial repository structure and project documentation.
- Phase 1 offline manifest-validation foundation.
- Phase 3 provider contract, provider discovery boundary, and GitHub Releases reference provider.
- Phase 4 deterministic update discovery and decision engine, including release and artifact eligibility, target resolution, and provider integration.
- Phase 5 controlled download engine with request validation, HTTPS and destination safety, streamed acquisition, temporary-file publication, cancellation, structured failures, recoverability, and download-result handoff.
- Phase 5 download-result contract documenting the separation between successful acquisition and later artifact trust or installation readiness.
- Phase 6 installer engine boundaries for installer input validation, descriptor/capability validation, installer selection, controlled invocation, process lifecycle semantics, plugin operation integration, and structured installation results.
- Phase 7 orchestration input boundary carrying a parent operation correlation identifier and normalized application-management inputs.
- Phase 7 deterministic stage planning, immutable operation state, stage transitions, cancellation control flow, single-stage coordination, multi-stage workflow coordination, and lifecycle coordination.
- Phase 7 lifecycle and orchestration audit/lock documentation.
- Phase 8 public CLI/result contracts for the supported PowerShell commands.
- Phase 8 user-facing Getting Started, CLI reference, manifest-authoring, and diagnostics/troubleshooting documentation.
- Phase 8 release packaging boundary, independent release validation, and versioned package assembly tooling.
- Phase 8E managed installed-state persistence, update-decision composition, and controlled engine N→N+1 upgrade tooling.
- Phase 8F GUI readiness contract and presentation-boundary audit coverage.
- Phase 9 complete Core-owned application update lifecycle, including artifact verification, post-install reconciliation, authoritative managed-state handling, and lifecycle failure/cancellation behavior.
- Phase 10 public `Invoke-WintainiumApplicationUpdate` command and stable public result projection.
- Phase 11A Windows/.NET GUI foundation audit and in-process PowerShell SDK hosting probe.

### Changed

- Roadmap now records Phases 4, 5, and 6 as complete and locked, and Phase 7 as implemented, validated, and locked through 7I.
- AI development context now reflects the implemented engine state through the Phase 7 orchestration lifecycle.
- Phase 6E installer process completion now uses the `WaitForExitAsync()` completion task as the authoritative normal-completion signal, preventing a later cancellation or timeout signal from retroactively reclassifying an already completed process.
- Phase 8A removed low-level installer request construction from the exported public PowerShell surface.
- Phase 8B aligned public command help and structured-result contract documentation with the actual three-command surface and established the boundary for the future public orchestration command.
- Phase 8C documentation now explicitly describes structured diagnostics, OperationId correlation, error-code handling, and operation-specific troubleshooting without inventing persistent configuration or update/install interfaces that do not yet exist.
- Phase 8D release packaging now defines deterministic file selection and relative layout, authoritative versioning, an explicit distributable boundary, independent package validation, preflight and overwrite protection, and cleanup after post-creation failure.
- Phase 8E established a narrow Wintainium-managed installed-state boundary, an internal update-decision composition seam, and a validated transactional program-file upgrade path while preserving durable user state outside the program root.
- Phase 8F audited public structured-result arrays, including empty collection behavior, and synchronized the public PowerShell/result contracts with the completed persistence boundary. The future GUI remains a presentation client of Core rather than a second orchestration engine.
- Phase 10 established a dedicated public update parameter boundary, explicit default forwarding, a projection-only public result contract, and structured early StateRoot failure handling without exposing internal orchestration dependencies.
- Phase 10 documentation now identifies the four-command public surface and describes the completed update lifecycle consistently across the CLI reference, Getting Started guide, README, roadmap, and public PowerShell contract.

### Phase 8D lock

- Phase 8D is complete and locked after the 356/356 full-suite regression checkpoint. The release boundary is ready for the Phase 8E upgrade and persistence contract work.

### Phase 8E checkpoint

- Phase 8E is complete after the controlled engine upgrade transaction and hardening. The full-suite checkpoint before the 8F audit was **377/377 green**.

### Phase 8F lock

- Phase 8F is complete and locked after the GUI readiness audit and **382/382 green** full-suite regression checkpoint. The public presentation boundary is documented, tested, and intentionally stops short of an incomplete end-to-end update command.

### Phase 12.12 — Integration, Regression, Audit & Lock

- Added `docs/Phase12BIntegrationAudit.md` defining the final Phase 12B vertical-slice audit, regression checkpoints, test-fixture boundary, and lock boundary.
- Reconciled Phase 12 source-resolution documentation and roadmap status with the implemented GitHub, structured official-download-page, and unsupported/interactive source handling work.
- Final checkpoints passed: **14/14** focused Core onboarding tests, **4/4** live source-resolution integration tests, successful x64 Debug desktop build, and **6/6** desktop source-resolution UX scenarios on 2026-09-22.
- **Phase 12B is complete and locked.** The lock remains limited to source onboarding/source resolution and does not claim live validation of downstream update-execution stages.

### Phase 12.11 — Unsupported/Interactive Source Handling

- Added structured unsupported/ambiguous/unavailable/authentication-required/interactive/source-response-invalid onboarding outcome coverage.
- Added the Debug-only desktop plugin-root override used to validate presentation of deterministic source-resolution failures without shipping the test provider in the production plugin set.
- Added desktop UX mapping for source-resolution outcomes, including OS-level Open Source actions for authentication-required and interactive-resolution cases.
- The focused Core regression is **14/14 green**, and the desktop manual source-resolution checkpoint is **6/6 passed**.

### Phase 10 checkpoint

- Phase 10C implementation and audit work is complete. The focused public-contract regression is **58/58 green**.
- Phase 10G public-command end-to-end regression coverage now exercises the complete successful lifecycle and no-update path; the existing lifecycle failure matrix, authoritative-state, and cancellation regressions cover verification hard-gate, installer failure, reconciliation failure, persistence failure, cancellation, Unknown evidence, and OperationId preservation. Phase 10 is complete and locked. The final full Phase 1–10 regression is **454/454 green**.

### Phase 11A checkpoint

- Phase 11A validated the Windows/.NET toolchain baseline, restored and built the official WinUI 3 C# template, and proved in-process Microsoft.PowerShell.SDK 7.6.6 hosting from .NET 10 without changing machine execution policy.
- The probe imported Wintainium.Core, resolved Get-WintainiumManifest, executed it successfully, and demonstrated structured result transfer across the C# / PowerShell boundary.
- GUI-readiness, project, and AI orientation documentation were reconciled with the completed Phase 10 four-command public surface. Phase 11A is complete; the production GUI project begins in Phase 11B.

## Phase 11B — GUI Project Foundation

- Added the production `src/Wintainium.Desktop` WinUI 3 / .NET 10 project foundation.
- Established the WinUI application lifecycle and minimal window boundary.
- Kept product appearance and desktop shell decisions intentionally deferred to later Phase 11 work.
- Preserved the presentation-only boundary; no Core engine integration is introduced by 11B.

### Phase 11C — Windows Application Shell

- Added the initial single-window Wintainium desktop shell and software-collection landing surface.
- Added main-window Sort & Filter and Add Software interaction points.
- Added the separate Settings window with General, Appearance, Updates, Sources, and Advanced categories.
- Established Source URL as the Add Software shell input and reserved Wintainium's own release history for Settings > Updates.
- Preserved the presentation-only boundary; no Core engine integration or application-state inference is introduced by 11C.
- Hardened the Settings window with functional category presentation and safe close/reopen lifecycle handling.
- Recorded the agreed Sort & Filter choices, distinct Unknown installed-state semantics, and downstream Details requirements for Do Not Update and editable Notes.
- Phase 11C passed the local WinUI build checkpoint and is now complete and locked. The shell's executable identity is `Wintainium.exe`; Core integration and application-model work continue in downstream Phase 11 batches.


### Phase 11K — GUI Foundation Audit & Phase 11 Lock

- Added `docs/Phase11GuiAudit.md` documenting the final architectural audit of the C#/.NET/WinUI desktop boundary.
- Reconciled GUI readiness, project, configuration, testing, and AI development documentation with the implemented lifecycle and cancellation presentation semantics.
- Completed the final Phase 11 architectural audit with no provider/installer coupling, console parsing, undocumented contract dependency, duplicated engine authority, or unstructured diagnostic dependency identified.
- Final desktop checkpoint passed and the complete Phase 1–10 PowerShell/Pester regression is **454/454 green**.
- Phase 11 is now **complete and locked**.

### Phase 11J — GUI Testing & Integration Hardening

- Expanded the desktop EngineProbe to cover structured operation state, diagnostic preservation, session-scoped settings, and the desktop cancellation boundary.
- Added `docs/DesktopTesting.md` with the focused automated and WinUI interaction/window-lifecycle checkpoint.
- Phase 11J passed the local WinUI build and desktop interaction checkpoint and is now complete and locked. No Core/PowerShell changes were required.

### Phase 11D — Engine Integration Boundary

- Added the in-process C#/.NET PowerShell SDK hosting boundary for the desktop client.
- Restricted desktop-hosted command invocation to the four documented Wintainium.Core public commands.
- Preserved structured PowerShell results and errors below the adapter-facing application boundary; terminal output is not used as an API.
- Added cancellation-aware hosted pipeline stopping with race-safe cancellation classification.
- Added an executable adapter contract probe covering real Core invocation, structured manifest results, and public-command allow-list enforcement.
- Phase 11D is complete and locked after the adapter build and contract-probe checkpoint passed.
