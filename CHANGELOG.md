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

### Changed

- Roadmap now records Phases 4, 5, and 6 as complete and locked, and Phase 7 as implemented, validated, and locked through 7I.
- AI development context now reflects the implemented engine state through the Phase 7 orchestration lifecycle.
- Phase 6E installer process completion now uses the `WaitForExitAsync()` completion task as the authoritative normal-completion signal, preventing a later cancellation or timeout signal from retroactively reclassifying an already completed process.
- Phase 8A removed low-level installer request construction from the exported public PowerShell surface.
- Phase 8B aligned public command help and structured-result contract documentation with the actual three-command surface and established the boundary for the future public orchestration command.
- Phase 8C documentation now explicitly describes structured diagnostics, OperationId correlation, error-code handling, and operation-specific troubleshooting without inventing persistent configuration or update/install interfaces that do not yet exist.
- Phase 8D release packaging now defines deterministic file selection and relative layout, authoritative versioning, an explicit distributable boundary, independent package validation, preflight and overwrite protection, and cleanup after post-creation failure.

### Phase 8D lock

- Phase 8D is complete and locked after the 356/356 full-suite regression checkpoint. The release boundary is ready for the Phase 8E upgrade and persistence contract work.
