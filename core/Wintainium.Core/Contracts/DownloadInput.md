# Phase 5A Download Input Boundary Contract

## Purpose

Phase 5A defines the Core-owned boundary between a completed Phase 4 update decision and the download engine.

The download engine does not accept arbitrary download instructions. It accepts a structured download request derived directly from a Phase 4 `UpdateDecision` whose status is `UpdateAvailable`.

## Input

`New-WintainiumDownloadRequest -UpdateDecision <UpdateDecision>` accepts a Phase 4 update decision and returns a download request with:

- `OperationId` — a new Core-generated operation correlation identifier.
- `UpdateDecision` — the original decision object, retained without reinterpretation.
- `SelectedRelease` — the exact selected release from the decision.
- `SelectedArtifact` — the exact selected artifact from the decision.

The selected artifact is not copied, substituted, or reselected by Phase 5A.

## Required Decision State

A download request may be created only when all of the following are true:

- `Status` exists and equals `UpdateAvailable`.
- `IsUpdateAvailable` exists and is `$true`.
- `SelectedRelease` exists and is non-null.
- `SelectedArtifact` exists and is non-null.

Other Phase 4 statuses do not authorize a download request.

## Phase Boundary

Phase 5A validates the provenance and structural completeness of the download input. It does not validate or normalize the artifact URI, destination filename, network policy, or filesystem destination. Those concerns belong to later Phase 5 safety boundaries.

Phase 5A performs no network access, filesystem writes, artifact verification, installer selection, or installation.

## Trust Boundary

`SelectedArtifact` remains provider-derived source metadata. Creating a download request does not establish that its URI, filename, hashes, signatures, or other metadata are trustworthy. Later Phase 5 stages must independently apply Core-owned download and destination policy.

A successful Phase 5A request therefore means only:

> Phase 4 selected an artifact and Phase 5 has accepted that selection as the input to its controlled download pipeline.
