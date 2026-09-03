# Phase 6C — Installer Selection Contract

## Purpose

Phase 6C defines the Core-owned boundary that selects the installer plugin applicable to a selected Phase 4 artifact.

Installer selection is a deterministic Core decision. Installer plugins do not select themselves, inspect the artifact, or execute during selection.

## Inputs

`Select-WintainiumInstaller -Manifest <ApplicationDefinition> -Artifact <SelectedArtifact> -Plugins <PluginRegistry>` accepts:

- a validated application manifest containing the required installer plugin reference;
- the selected Phase 4 artifact, including its explicit `format`; and
- the validated installer plugin registry.

The selected artifact's format is authoritative for this boundary. Core does not infer an artifact format from a filename or executable contents.

## Selection rules

Core selects an installer only when all of the following are true:

1. The manifest declares an installer plugin identifier and required contract version.
2. A registered installer plugin matches the manifest-declared plugin identifier.
3. The registered plugin declares the required contract version.
4. The selected artifact explicitly declares a format.
5. The installer descriptor declares that format in `capabilities.supportedFormats`.

Format comparison is case-insensitive and whitespace around the explicit format is normalized for comparison.

A missing artifact format is an error. Core does not guess from the artifact filename, URI, or executable contents.

## Result

A successful selection returns:

- `IsSelected = true`;
- `InstallerPlugin` — the resolved validated installer descriptor;
- `ArtifactFormat` — the selected artifact's declared format; and
- `Error = $null`.

A failed selection returns:

- `IsSelected = false`;
- `InstallerPlugin = $null`;
- the supplied artifact format when available; and
- a structured error describing why selection could not proceed.

## Trust boundary

Successful installer selection does **not** establish that artifact bytes are authentic, untampered, hash-verified, signature-valid, trusted, safe to execute, or approved for installation.

Selection also does not construct commands, arguments, environment variables, working directories, elevation requests, or process invocations.

## Phase boundary

Phase 6B establishes what installer plugins claim to support. Phase 6C consumes those validated capabilities to select the applicable installer for the already-selected artifact.

Phase 6C does not verify artifact trust or execute installer code. Controlled invocation and process lifecycle behavior belong to later Phase 6 boundaries.
