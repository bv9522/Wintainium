# Phase 6A — Installer Input Boundary Contract

## Purpose

Phase 6A defines the Core-owned boundary between a completed Phase 5 download and the Installer Engine.

The installer engine does not accept arbitrary executable instructions. It accepts a structured installer request derived from a completed download result and a validated application manifest.

## Input

`New-WintainiumInstallerRequest -DownloadResult <DownloadResult> -Manifest <ApplicationDefinition>` accepts:

- a Phase 5 download result whose `Status` is `Downloaded`;
- a completed local artifact represented by `DestinationPath`;
- a validated application manifest containing an installer plugin reference.

The request creates a new installer `OperationId` and preserves the originating Phase 5 `OperationId` as `DownloadOperationId`.

## Required Download State

The download result must contain the operation, status, URI, filename, and destination properties. The status must be `Downloaded`.

`DestinationPath` must be an absolute path to an existing file. The input boundary does not reinterpret the path, select a different artifact, or execute the file.

## Required Installer Reference

The application manifest must declare an `Installer` reference containing:

- `pluginId` — a valid `Wintainium.installer.*` identifier;
- `requiredContractVersion` — a positive major contract version;
- `settings` — an object, including an empty object when no plugin-specific settings are required.

The manifest's installer reference is preserved as the request's installer selection input. Phase 6A does not resolve or execute the plugin.

## Request Shape

A successful request contains:

- `OperationId` — a new Core-generated installer operation identifier;
- `DownloadOperationId` — the originating Phase 5 operation identifier;
- `Manifest` — the validated application definition supplied to the boundary;
- `Installer` — the manifest's installer plugin reference;
- `Artifact.Uri` — the URI recorded by the completed download;
- `Artifact.FileName` — the filename recorded by the completed download;
- `Artifact.Path` — the completed local artifact path.

A failed request contains `IsValid = false`, `Request = $null`, and structured validation errors.

## Trust Boundary

A successful installer request means only that a completed local artifact and an installer plugin reference have passed the Phase 6A structural input checks.

It does **not** establish that the artifact is:

- authentic;
- untampered;
- hash-verified;
- signature-valid;
- trusted;
- safe to execute; or
- approved for installation.

Phase 6A therefore contains no verification, signature evaluation, trust decision, installer selection beyond the manifest-declared reference, process creation, or execution behavior.

## Phase Boundary

Phase 5 remains responsible for controlled acquisition. Phase 6A accepts its completed artifact handoff.

Later Phase 6 boundaries are responsible for installer descriptor/capability validation, selection/resolution, controlled invocation, process lifecycle semantics, and structured installation results.

The request boundary must not absorb Phase 7 orchestration or post-install application-state reconciliation.
