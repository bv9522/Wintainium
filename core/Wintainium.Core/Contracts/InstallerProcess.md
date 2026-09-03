# Phase 6E — Installer Process Lifecycle Contract

## Purpose

Phase 6E defines the Core-owned process boundary used when an installer operation must execute a native process.

The boundary is intentionally lower-level than the installer result contract. It owns process creation, argument boundaries, standard-output/error capture, exit-code observation, timeout, cancellation, and termination. Phase 6F interprets the controlled execution outcome as a structured installation result.

## Process launch rules

`Invoke-WintainiumInstallerProcess` accepts:

- an absolute executable path;
- a structured string array of arguments;
- an optional absolute working directory;
- optional structured environment-variable overrides;
- a positive timeout in milliseconds; and
- an optional `CancellationToken`.

The process is created with `UseShellExecute = false`, redirected standard output/error, and no shell window. Arguments are supplied through `ProcessStartInfo.ArgumentList`; Core does not build a shell command line.

Relative executable paths, missing executables, invalid working directories, and invalid environment-variable names are rejected before process creation.

No `cmd.exe /c`, PowerShell `Invoke-Expression`, shell operators, pipelines, redirection syntax, or implicit executable discovery is used by this boundary.

## Lifecycle semantics

The process lifecycle has four terminal outcomes:

- `Completed` — the process exited with code `0`;
- `Failed` with `FailureKind = NonZeroExit` — the process exited with a non-zero code;
- `Failed` with `FailureKind = Timeout` — the configured timeout elapsed before normal completion; or
- `Failed` with `FailureKind = Cancelled` — the supplied cancellation token was signaled before normal completion.

A process that times out or is cancelled is terminated through the process API, including its process tree where supported by the runtime. Wintainium does not leave a timed-out installer process running in the background.

Process-start failures return `FailureKind = ProcessStart` and never report an exit code.

## Captured execution data

Every terminal result contains:

- `Status`;
- `FailureKind`;
- `ExitCode` when a process exit code is known;
- `StandardOutput`;
- `StandardError`;
- `DurationMilliseconds`; and
- `ErrorMessage` when a Core-owned failure description is available.

Standard output and standard error are captured independently so installer diagnostics are not discarded.

## Security boundary

The process boundary does not establish artifact authenticity, integrity, signature validity, trust, or approval to install. It also does not infer an executable from an artifact filename or format.

The caller is responsible for supplying an explicitly selected executable and explicitly structured arguments. A successful process exit only means that the launched process returned exit code `0`.

## Phase boundary

Phase 6D prepares the constrained installer handoff. Phase 6E owns native process lifecycle semantics when such a process is required. Phase 6F owns the structured installation result and its interpretation. Post-install state reconciliation remains outside Phase 6E.
