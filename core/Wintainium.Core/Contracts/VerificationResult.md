# Phase 9B — Artifact Verification Result Contract

## Purpose

Phase 9B establishes the Core-owned boundary between a completed download and authorization to enter the installer pipeline.

Verification evaluates the bytes at the exact downloaded `DestinationPath` against trusted Core-supported cryptographic evidence carried as artifact metadata. Download success alone never satisfies this boundary.

## Input

The verification operation accepts:

- `DownloadResult` — a successful Phase 5 result with `Status = Downloaded`;
- `SelectedArtifact` — the exact artifact selected by the Phase 4 decision; and
- the shared lifecycle `OperationId` when supplied by orchestration.

The destination path comes from `DownloadResult`. Verification does not download, relocate, or execute the artifact.

## Supported Evidence

The initial Core verification policy supports cryptographic `SHA256` hash claims in the artifact's `Hashes` metadata.

A hash claim is normalized as an object with:

- `Algorithm` — `SHA256`, case-insensitive;
- `Value` — the expected hexadecimal digest.

For compatibility with provider output, `Hashes` may be a collection of such objects or a dictionary whose keys are algorithms and values are digests. The verification boundary normalizes these forms without treating arbitrary metadata as executable instructions.

At least one valid SHA-256 claim is required. Unsupported-only, missing, or malformed verification metadata cannot establish verification and therefore blocks installation.

## Result Shape

`Invoke-WintainiumArtifactVerification` returns:

- `OperationId` — the supplied lifecycle correlation identifier, or `$null` when invoked without one;
- `Status` — `Verified` or `Failed`;
- `FailureKind` — `$null` on success, otherwise a stable verification failure category;
- `Algorithm` — `SHA256` on a successful hash verification;
- `ExpectedHash` — the normalized expected digest used for the successful verification;
- `ActualHash` — the digest calculated from the exact downloaded file;
- `DestinationPath` — the verified local artifact path;
- `ErrorMessage` — human-readable diagnostics only.

## Verification Rules

- The download result must be present and have `Status = Downloaded`.
- The destination must exist as a regular file.
- The selected artifact must be present.
- At least one valid SHA-256 claim must be available.
- Every SHA-256 claim supplied by the artifact must agree with the calculated digest.
- A matching digest establishes integrity against the supplied cryptographic claim; it does not by itself assert vendor identity or code safety.
- No installer operation may begin from a failed verification result.

## Failure Categories

The initial operation reports:

- `InputInvalid` — required input is missing or structurally invalid.
- `DownloadNotCompleted` — the download result is not a successful `Downloaded` handoff.
- `ArtifactMissing` — the selected artifact is missing.
- `DestinationMissing` — the completed download path does not exist as a file.
- `VerificationMetadataMissing` — no hash evidence is available.
- `VerificationMetadataInvalid` — hash evidence is malformed or contains an invalid digest.
- `UnsupportedVerificationAlgorithm` — hash metadata exists but contains no supported SHA-256 evidence.
- `HashMismatch` — the calculated digest does not match a declared SHA-256 claim.
- `VerificationFailed` — the file-hash operation itself failed.

## Operation Identity

When an orchestration `OperationId` is supplied, the verification result preserves it unchanged. Verification does not create a competing lifecycle identity.

## Boundary Ownership

Verification owns cryptographic comparison of downloaded bytes. It does not perform provider discovery, update decisions, downloading, installer selection, installation, reconciliation, or managed-state persistence.

## Security Boundary

Artifact metadata remains source-derived input until verification succeeds. Filenames, URIs, signatures that are not supported by this policy, and release versions are not treated as proof of artifact integrity.

The verification operation never invokes the artifact or interprets metadata as a command.
