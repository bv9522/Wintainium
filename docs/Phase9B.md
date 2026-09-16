# Phase 9B — Artifact Verification Engine

## Objective

Implement the missing Core-owned verification boundary identified during the Phase 9 audit.

## Basis from audit

Phase 4 already preserves provider-declared artifact `Hashes` and `Signature` metadata as untrusted observations. Phase 5 explicitly states that a successful download does not establish integrity, authenticity, signature validity, or installation readiness. Phase 6 explicitly states that installer success does not establish application state.

Therefore Phase 9 needs a real verification operation between download and installation rather than treating the download result as trusted input.

## Initial policy

The first Core verification implementation supports SHA-256 digest comparison. A successful verification requires a completed download, an existing destination file, and valid SHA-256 evidence supplied by the selected artifact.

This is deliberately narrower than a general signature/trust framework. Signature metadata remains unsupported until a separate contract defines its semantics and trust roots.

## Exit criteria

- Verification has a stable structured result contract.
- Exact downloaded bytes are hashed by Core.
- Matching SHA-256 evidence produces `Verified`.
- Missing, malformed, unsupported, or mismatched evidence produces a structured failure.
- Download success cannot bypass verification.
- Verification never executes or relocates the artifact.
- OperationId can be supplied by the lifecycle and is preserved.
- Regression tests cover success, mismatch, missing evidence, malformed evidence, unsupported algorithms, incomplete download, dictionary metadata, and non-execution behavior.

## Follow-on

9C will define the dedicated reconciliation-provider contract. 9D will compose verification and reconciliation with the existing lifecycle without moving orchestration policy into the public caller.
