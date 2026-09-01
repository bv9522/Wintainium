# Phase 5 — Download Engine Lock

## Purpose

Phase 5 obtains the artifact selected by the locked Phase 4 update decision through a controlled Core-owned download boundary. It ends when acquisition has either produced a completed local artifact or returned a structured recoverable/non-recoverable failure.

Phase 5 does not establish artifact trust and does not install software.

## Phase 5A–5B: Input and target safety

- `New-WintainiumDownloadRequest` accepts only a Phase 4 `UpdateAvailable` decision containing a selected release and selected artifact.
- The request preserves the selected artifact rather than inventing or replacing it.
- The request receives a Core-generated `OperationId` used to correlate the request and result.
- URI and destination validation occur after the input boundary.
- `Resolve-WintainiumDownloadTarget` requires an absolute HTTPS URI, rejects malformed/unsupported destinations and URI user information, and confines the final path to the Core-controlled download root.
- Windows filename safety rules and reserved device names are enforced before acquisition.

## Phase 5C: Controlled acquisition

`Invoke-WintainiumDownload` owns the actual byte transfer.

- Uses `HttpClient` and `ResponseHeadersRead` for controlled streaming.
- Supports dependency-injected `HttpClient` instances for deterministic tests.
- Supports cancellation through a `CancellationToken`.
- Writes to a uniquely named temporary file inside the controlled download root.
- Publishes the completed artifact only after the transfer finishes.
- Does not invoke installers, execute downloaded content, or perform trust verification.

## Phase 5D: Failure and recovery

Expected acquisition failures are represented structurally rather than by requiring callers to parse exception text.

Current failure categories:

- `DestinationExists` — the final destination is already occupied; not automatically retryable.
- `Network` — the network operation could not be established/completed; retryable.
- `Http` — the upstream returned a non-success response; retryability follows HTTP status policy (`5xx`, `408`, and `429` are retryable).
- `Transfer` — the response body could not be completely transferred; retryable.
- `Cancelled` — cancellation interrupted acquisition; not automatically retryable.
- `DestinationWrite` — the completed temporary artifact could not be published; retryable.

Temporary files are removed during cleanup after both successful publication and failure paths. Partial bytes may be reported for transfer/cancellation failures but are never presented as a completed artifact.

## Phase 5E: Result and artifact handoff

`Invoke-WintainiumDownload` returns one structured result containing:

- `OperationId`
- `Status`
- `FailureKind`
- `Uri`
- `FileName`
- `DestinationPath`
- `BytesWritten`
- `Retryable`
- `ErrorMessage`

A successful result uses `Status = 'Downloaded'`, points to the completed local artifact, and reports its completed length. A failure uses `Status = 'Failed'` and identifies the failure category and retryability.

A successful download means only that Wintainium acquired and published bytes. It does not mean the artifact is authentic, untampered, hash-verified, signature-valid, safe to execute, or suitable for installation.

## Phase 5F: Phase 4 integration

The Phase 4 boundary remains authoritative:

`UpdateDecision` → `New-WintainiumDownloadRequest` → `Invoke-WintainiumDownload` → structured download result.

Phase 5 does not re-select a release or artifact. It consumes the selected artifact from Phase 4 and validates only the acquisition target and destination requirements necessary to download it safely.

The integration test proves request correlation, selected artifact preservation, completed publication, and result handoff without introducing installation or verification behavior.

## Phase 5G: Lock criteria

Phase 5 is considered complete when:

1. The download input, target, operation, failure/recovery, result, and integration contracts are implemented and tested.
2. Temporary downloads cannot become accidental completed artifacts.
3. Destination safety and overwrite protection are enforced before publication.
4. Download success is explicitly separated from trust and installation readiness.
5. Phase 4 remains unchanged as the source of the selected update target.
6. Phase 6 responsibilities—artifact verification, installer selection, and execution—are absent from the Phase 5 implementation and result contract.
7. The full Pester suite passes.

## Verification checkpoint

The Phase 5 implementation is covered by the unit and integration suites under `tests/Unit/Download*.Tests.ps1` and `tests/Integration/DownloadWorkflow.Tests.ps1`. The final observed full-suite checkpoint for this lock is **164/164 tests passed** on PowerShell 7.6.5 / Pester 6.1.0 in the ARM64 Ubuntu test environment.

That environment is a secondary validation environment only. Wintainium remains a Windows-first PowerShell application; the Android/Termux environment does not define the production runtime.
