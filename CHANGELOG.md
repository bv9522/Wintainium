# Changelog

All notable changes will be documented in this file.

This project intends to follow the principles of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and semantic
versioning once releases begin.

## [Unreleased]

### Added

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

### Phase 10 checkpoint

- Phase 10C implementation and audit work is complete. The focused public-contract regression is **58/58 green**.
- Phase 10G public-command end-to-end regression coverage now exercises the complete successful lifecycle and no-update path; the existing lifecycle failure matrix, authoritative-state, and cancellation regressions cover verification hard-gate, installer failure, reconciliation failure, persistence failure, cancellation, Unknown evidence, and OperationId preservation. Phase 10 remains pending the final full Phase 1–10 Pester checkpoint.
