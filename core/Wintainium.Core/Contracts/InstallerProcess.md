# Phase 6E — Installer Process Lifecycle Contract

## Purpose

Phase 6E defines the Core-owned process boundary used when an installer operation must execute a native process.

The boundary is intentionally lower-level than the installer result contract. It owns process creation, argument boundaries, standard-output/error capture, exit-code observation, timeout, cancellation, elevation handling, and termination. Phase 6F interprets the controlled execution outcome as a structured installation result.

## Process launch rules

`Invoke-WintainiumInstallerProcess` accepts:

- an absolute executable path;
- a structured string array of arguments;
- an optional absolute working directory;
- optional structured environment-variable overrides;
- a positive timeout in milliseconds; and
- an optional `CancellationToken`.

The normal process path is created with `UseShellExecute = false`, redirected standard output/error, and no shell window. Arguments are supplied through `ProcessStartInfo.ArgumentList`; Core does not build a shell command line.

If Windows rejects the normal process creation with `ERROR_ELEVATION_REQUIRED` (740), Core retries the same explicitly selected executable and argument list through the Windows `runas` shell verb. This is demand-driven elevation: Wintainium does not elevate every executable and does not infer elevation from an application name or filename.

The elevated path intentionally does not redirect standard output/error because Windows shell execution does not support the same redirected-stream contract. Process completion and exit code remain authoritative. If the user cancels the UAC prompt, the operation returns `FailureKind = ElevationDenied`.

Relative executable paths, missing executables, invalid working directories, and invalid environment-variable names are rejected before process creation.

A cancellation token that is already signaled is honored before process creation. Wintainium does not launch an installer when the operation has already been cancelled.

No `cmd.exe /c`, PowerShell `Invoke-Expression`, shell operators, pipelines, redirection syntax, or implicit executable discovery is used by the normal process boundary.

## Lifecycle semantics

The process lifecycle has these terminal outcomes:

- `Completed` — the process exited with code `0`;
- `Failed` with `FailureKind = NonZeroExit` — the process exited with a non-zero code;
- `Failed` with `FailureKind = Timeout` — the configured timeout elapsed before normal completion;
- `Failed` with `FailureKind = Cancelled` — the supplied cancellation token was signaled before normal completion;
- `Failed` with `FailureKind = ElevationDenied` — Windows elevation was required and the UAC request was cancelled or denied; or
- `Failed` with `FailureKind = ProcessStart` — process creation failed for another reason.

A process that times out or is cancelled is terminated through the process API, including its process tree where supported by the runtime. Wintainium does not leave a timed-out or cancelled installer process running in the background.

When normal process completion and a timeout/cancellation signal become observable at the same lifecycle boundary, normal process completion wins. Once the process has completed, Wintainium does not reclassify that invocation as interrupted.

Process-start failures never report an exit code.

## Captured execution data

Every terminal result contains:

- `Status`;
- `FailureKind`;
- `ExitCode` when a process exit code is known;
- `StandardOutput`;
- `StandardError`;
- `DurationMilliseconds`; and
- `ErrorMessage` when a Core-owned failure description is available.

Standard output and standard error are captured independently on the normal non-elevated path. Elevated shell execution returns empty output streams because the shell launch cannot use the normal redirection mechanism.

## Security boundary

The process boundary does not establish artifact authenticity, integrity, signature validity, trust, or approval to install. It also does not infer an executable from an artifact filename or format.

The caller is responsible for supplying an explicitly selected executable and explicitly structured arguments. A successful process exit only means that the launched process returned exit code `0`.

Elevation is performed only after Windows explicitly reports that the selected executable requires it. Core reuses the same validated executable path and structured argument list; it does not construct a shell command line or substitute another executable.

## Phase boundary

Phase 6D prepares the constrained installer handoff. Phase 6E owns native process lifecycle semantics, including Windows elevation when required. Phase 6F owns the structured installation result and its interpretation. Post-install state reconciliation remains outside Phase 6E.
