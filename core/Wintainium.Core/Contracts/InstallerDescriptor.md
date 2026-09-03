# Phase 6B — Installer Descriptor and Capability Contract

## Purpose

Phase 6B defines the Core-owned descriptor contract used to describe an installer plugin's capabilities before installer selection or execution.

An installer descriptor is declarative metadata. It identifies a plugin and the artifact formats it can accept. It does not contain executable commands, arguments, shell expressions, or installation instructions.

## Required descriptor fields

An installer descriptor must contain:

- `pluginId` — a stable `Wintainium.installer.*` identifier;
- `pluginType` — `Installer`;
- `contractVersions` — one or more positive major installer contract versions;
- `capabilities` — an object containing `supportedFormats`.

`supportedFormats` must be a non-empty array of non-empty string format identifiers. Format identifiers are compared case-insensitively and are normalized to lowercase by the descriptor validation boundary.

Format identifiers are intentionally extensible. Core validates their shape but does not maintain a universal list of installer formats.

## Capability semantics

`capabilities.supportedFormats` answers:

> Which artifact formats can this installer plugin accept at its installer boundary?

The capability declaration does not authorize execution, establish artifact trust, or imply support for every possible invocation option associated with a format.

Additional capability fields may be added through a future contract version. Unknown capability fields are preserved as descriptor metadata and do not become Core behavior merely by appearing in a descriptor.

## Validation

The Core descriptor boundary validates installer-specific requirements before a descriptor enters the plugin registry.

Invalid installer descriptors are rejected when:

- the plugin identity or type is invalid;
- no compatible contract version is declared;
- `capabilities` is not an object;
- `supportedFormats` is missing or empty;
- a supported format is not a string;
- a supported format is empty or malformed; or
- duplicate supported formats are declared.

Validation is structural and deterministic. It does not load installer code, inspect executable contents, execute a plugin, or access the network.

## Phase boundary

Phase 6B defines what an installer plugin claims to support.

It does **not**:

- choose an installer plugin;
- verify downloaded artifact bytes;
- establish trust or signature validity;
- construct installer command lines;
- execute installer processes; or
- reconcile installed application state.

Installer selection belongs to Phase 6C. Controlled invocation and process lifecycle behavior belong to later Phase 6 boundaries.
