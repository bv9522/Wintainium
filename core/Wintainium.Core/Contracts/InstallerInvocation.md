# Phase 6D — Controlled Installer Invocation Contract

## Purpose

Phase 6D defines the Core-owned boundary that prepares a selected installer plugin for controlled process invocation.

The invocation contract is declarative and deterministic. It describes the executable, argument vector, working directory, environment overrides, and elevation policy required by a selected installer. It does not itself start a process.

## Inputs

`New-WintainiumInstallerInvocation -Selection <InstallerSelection> -Request <InstallerRequest>` accepts the successful Phase 6C installer selection and the validated Phase 6A installer request.

The selected installer plugin is authoritative for the invocation definition. Core does not infer installer commands from artifact filenames, formats, or executable contents.

## Invocation rules

A valid invocation must provide:

- an explicit executable path;
- an explicit argument collection, which may be empty;
- a valid working directory when one is supplied;
- environment overrides as structured key/value data when supplied; and
- an explicit elevation policy.

The executable path must be absolute and resolve to an existing file. Relative executable paths are rejected.

Arguments are represented as individual values rather than a single shell command line. Core does not invoke `cmd.exe`, PowerShell, or another shell as an implicit command interpreter.

No arbitrary command text, shell operators, redirection, pipelines, or implicit execution behavior are accepted as an invocation boundary.

Elevation is explicit. Phase 6D does not elevate implicitly and does not authorize elevation merely because an installer normally requires administrative rights.

## Result

A successful invocation preparation returns:

- `IsValid = true`;
- `ExecutablePath`;
- `Arguments`;
- `WorkingDirectory`;
- `Environment`;
- `Elevation`; and
- `Error = $null`.

A failed preparation returns `IsValid = false`, no executable invocation payload, and a structured error.

## Trust boundary

Invocation preparation does **not** establish artifact authenticity, integrity, signature validity, trust, or safety. Those concerns remain separate from process execution policy.

Preparing an invocation also does not start the installer, wait for it, interpret its exit code, handle cancellation, or reconcile installed application state.

## Phase boundary

Phase 6C selects the applicable installer. Phase 6D prepares a constrained process invocation for that selected installer. Phase 6E owns process lifecycle, exit, timeout, and cancellation semantics. Later boundaries own structured installation results and state reconciliation.
