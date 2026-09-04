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

### Changed

- Roadmap now records Phases 4, 5, and 6 as complete and locked, and Phase 7 as in progress.
- AI development context now reflects the implemented engine state through the Phase 7 kickoff.
