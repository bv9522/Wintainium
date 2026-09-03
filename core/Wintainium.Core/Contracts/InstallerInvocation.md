# Phase 6D — Controlled Installer Invocation Contract

## Purpose

Phase 6D defines the Core-owned boundary that prepares a selected installer plugin for controlled invocation.

The invocation contract is declarative and deterministic. It identifies the validated installer plugin module, the completed artifact it will receive, and the structured installer settings it may consume. It does not itself execute the plugin or start the vendor installer.

## Inputs

`New-WintainiumInstallerInvocation -Selection <InstallerSelection> -Request <InstallerRequest>` accepts the successful Phase 6C installer selection and the validated Phase 6A installer request.

The selected installer plugin is authoritative for its declared entry point. Core does not infer installer commands from artifact filenames, formats, or executable contents.

## Invocation rules

A valid invocation must provide:

- a successful installer selection;
- a selected installer plugin with a non-empty `PluginId`;
- an installer request whose declared `pluginId` matches the selected plugin identifier case-insensitively;
- a selected installer plugin with an `entryPoint`;
- an absolute descriptor path for the selected plugin, and an existing descriptor file;
- a relative `.psm1` entry point that remains within the plugin directory;
- an existing completed artifact file;
- a non-empty artifact format selected by Phase 6C; and
- structured installer settings.

The plugin entry point is resolved relative to the plugin descriptor directory. Absolute paths, parent-directory traversal, and non-`.psm1` entry points are rejected.

No arbitrary command text, shell operators, redirection, pipelines, or inferred executable instructions are accepted at this boundary.

## Result

A successful invocation preparation returns:

- `IsValid = true`; and
- `Invocation` containing `OperationId`, `DownloadOperationId`, `PluginId`, `PluginModulePath`, `ArtifactPath`, `ArtifactFormat`, and `Settings`.

A failed preparation returns `IsValid = false`, no invocation payload, and a structured error.

## Trust boundary

Invocation preparation does **not** establish artifact authenticity, integrity, signature validity, trust, or safety.

Preparing an invocation also does not execute plugin code, start a vendor installer, wait for a process, interpret an exit code, handle cancellation, or reconcile installed application state.

## Phase boundary

Phase 6C selects the applicable installer. Phase 6D prepares the constrained handoff to that installer's declared module entry point. Later Phase 6 boundaries govern execution/process lifecycle semantics and structured installation results.
