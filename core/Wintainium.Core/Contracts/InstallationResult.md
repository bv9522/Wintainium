# Phase 6F — Structured Installation Result Contract

## Purpose

Phase 6F defines the Core-owned result boundary for an installer operation after controlled process execution has completed.

The result records what the installer process actually reported. It does not claim that the target application is installed, updated, healthy, or reconciled with local application state. Those conclusions require later post-install validation and state reconciliation.

## Result semantics

`New-WintainiumInstallationResult` consumes:

- the validated installer invocation context from Phase 6D; and
- the controlled process result from Phase 6E.

A process result is considered a completed installation operation only when its status is `Completed` and its exit code is exactly `0`.

All other process outcomes remain failures and retain their original `FailureKind` where available. In particular:

- non-zero exit remains `NonZeroExit`;
- timeout remains `Timeout`;
- cancellation remains `Cancelled`; and
- process-start failure remains `ProcessStart`.

Phase 6F must not convert a non-zero exit, timeout, cancellation, or process-start failure into success.

## Result fields

Every structured installation result contains:

- `Status` — `Completed` or `Failed`;
- `FailureKind` — null for successful completion, otherwise a structured failure classification;
- `OperationId` — the operation identity propagated from the invocation context;
- `DownloadOperationId` — the acquisition identity when present;
- `PluginId` — the selected installer plugin identity when present;
- `ExitCode` — the native process exit code when known;
- `StandardOutput` — captured standard output;
- `StandardError` — captured standard error;
- `DurationMilliseconds` — controlled process duration; and
- `ErrorMessage` — Core-owned failure diagnostics when available.

The result preserves execution diagnostics rather than discarding installer output.

## Trust and installation boundary

A successful result means only that the selected installer process executed through the controlled process boundary and returned exit code `0`.

It does not establish:

- artifact authenticity;
- artifact integrity;
- signature validity;
- trust approval;
- successful installation of the intended application;
- successful update of the intended application;
- application health; or
- post-install state reconciliation.

Those concerns belong to their respective security, installation, validation, and orchestration boundaries.

## Invalid input handling

Missing invocation context and missing process results are represented as structured failures rather than being silently interpreted as successful installation.

The result layer does not execute processes, select installers, discover providers, download artifacts, or mutate application state.

## Phase boundary

Phase 6D prepares the installer invocation. Phase 6E executes the native process through the controlled lifecycle boundary. Phase 6F interprets that controlled execution outcome as a structured installation result. Later phases may use the result as an input to post-install validation and state reconciliation.
