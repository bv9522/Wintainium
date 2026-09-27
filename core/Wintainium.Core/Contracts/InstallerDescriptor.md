# Installer Descriptor Contract

## Purpose

An installer descriptor declares the capabilities of an installer plugin. It is declarative metadata only; it does not contain executable commands or authorize artifact execution.

## Required fields

- `pluginId` — unique `Wintainium.installer.*` identifier.
- `pluginType` — `Installer`.
- `contractVersions` — one or more positive major installer contract versions.
- `capabilities.supportedFormats` — non-empty array of artifact-format identifiers.

## Installation mechanism

Installers may additionally declare:

- `capabilities.installationMode` — a non-empty mechanism identifier such as `process`, `archive`, or `msix`.

The identifier is intentionally extensible rather than an exhaustive enum. Core owns the execution semantics for mechanisms it understands; a plugin declaring an unsupported mechanism cannot be executed merely because its artifact format is recognized.

For backward compatibility with existing Contract v1 installer plugins, an omitted `installationMode` is treated as `process`. New production installer plugins should declare their mechanism explicitly.

## Supported formats

`supportedFormats` describes plugin capability, not trust, authenticity, integrity, signature validity, or permission to execute an artifact. Format identifiers are normalized case-insensitively for compatibility checks.

A plugin may support more than one format when the same installation mechanism legitimately handles those formats.

## Security boundary

Installer descriptors do not contain shell commands, executable paths, arbitrary command text, or inferred installation instructions. Core remains responsible for selecting the plugin, validating the artifact and invocation boundary, and applying the mechanism-specific execution contract.
