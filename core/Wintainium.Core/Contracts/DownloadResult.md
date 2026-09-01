# Phase 5E Download Result / Artifact Handoff Contract

## Purpose

Phase 5E defines the Core-owned result boundary between the controlled download operation and later Wintainium stages.

A download result reports what happened during acquisition of the selected artifact. It does not establish artifact trust, authenticity, integrity, installer suitability, or installation readiness.

## Result Shape

`Invoke-WintainiumDownload` returns a structured result containing:

- `OperationId` — the correlation identifier from the download request, preserved unchanged when supplied.
- `Status` — `Downloaded` on successful completion, otherwise `Failed`.
- `FailureKind` — `$null` on success; a stable failure category when the operation fails.
- `Uri` — the resolved artifact URI used by the download operation.
- `FileName` — the validated destination filename.
- `DestinationPath` — the Core-controlled local destination associated with the operation.
- `BytesWritten` — bytes successfully written to the temporary file before completion, or the completed artifact length on success.
- `Retryable` — whether the reported failure may be retried under future retry policy; always `$false` on success.
- `ErrorMessage` — a human-readable failure description; `$null` on success.

`OperationId` provides correlation across the Phase 5 request/result boundary without making the result responsible for orchestration or logging policy.

## Successful Handoff

A successful result has:

- `Status = 'Downloaded'`.
- `FailureKind = $null`.
- `Retryable = $false`.
- `ErrorMessage = $null`.
- `DestinationPath` points to the completed local artifact.
- `BytesWritten` equals the completed artifact length.

The destination is published only after the transfer completes. The temporary download file is not part of the handoff contract.

## Failed Handoff

A failed result has `Status = 'Failed'` and identifies the applicable `FailureKind` and retryability. A failure result must not imply that a completed local artifact exists.

Partial transfer bytes may be reported through `BytesWritten` for transfer or cancellation failures, but partial data remains temporary and is not a usable artifact handoff.

## Failure Categories

The current controlled download operation reports these categories:

- `DestinationExists` — the intended destination already exists or became occupied before publication; not retryable by the current operation.
- `Network` — the HTTP operation could not be established or completed at the network layer; retryable.
- `Http` — the server returned a non-success HTTP response; retryability depends on the status code.
- `Transfer` — the response body could not be completely transferred; retryable.
- `Cancelled` — cancellation interrupted the operation; not retryable automatically.
- `DestinationWrite` — the completed temporary artifact could not be published to the destination; retryable.

## Artifact Trust Boundary

`Status = 'Downloaded'` means only that Wintainium successfully acquired bytes and published them to the controlled destination.

It does **not** mean that the bytes are:

- authentic,
- untampered,
- signed or signature-valid,
- hash-verified,
- safe to execute, or
- suitable for installation.

Those decisions belong to later phases. Phase 5E therefore does not add verification, signature, installer, or execution semantics to the download result.

## Recoverability

The result is structured so callers can distinguish completed acquisition from recoverable and non-recoverable failures without parsing log text. Temporary files are cleaned after failure, while a successful destination remains available for the next controlled pipeline stage.
