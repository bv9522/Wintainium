# Phase 6F — Structured Installation Result Contract

## Purpose

Phase 6F defines the Core-owned result boundary for an installer operation after controlled process execution has completed.

The result records what the installer process actually reported. It does not claim that the target application is installed, updated, healthy, or reconciled with local application state. Those conclusions require later post-install validation and state reconciliation.

## Result semantics

`New-WintainiumInstallationResult` consumes the validated installer invocation context from Phase 6D and the controlled process result from Phase 6E.

A process result is a completed installation operation only when its status is `Completed` and its exit code is exactly `0`. All other process outcomes remain failures and retain their original `FailureKind` where available.

## Result fields

Every structured installation result contains `Status`, `FailureKind`, `OperationId`, `DownloadOperationId`, `PluginId`, `ExitCode`, `StandardOutput`, `StandardError`, `DurationMilliseconds`, and `ErrorMessage`.

Identifiers are propagated from the invocation context. Execution diagnostics are propagated from the controlled process result. An exit code is null when the process did not produce a usable exit code, such as cancellation, timeout, or process-start failure.

## Trust and installation boundary

A successful result means only that the selected installer process executed through the controlled process boundary and returned exit code `0`.

It does not establish artifact authenticity, artifact integrity, signature validity, trust approval, successful installation of the intended application, successful update, application health, or post-install state reconciliation.

## Failure preservation

Non-zero exit, timeout, cancellation, and process-start failures are never converted into success by this boundary. If a controlled process result lacks a failure classification, the result uses `ProcessFailed` rather than silently treating the outcome as successful.

Missing invocation context and missing process results are represented as structured failures.

## Phase boundary

Phase 6D prepares the installer invocation. Phase 6E executes the native process through the controlled lifecycle boundary. Phase 6F interprets that controlled execution outcome as a structured installation result. Later phases may use the result as an input to post-install validation and state reconciliation.

The result layer does not execute processes, select installers, discover providers, download artifacts, or mutate application state.
