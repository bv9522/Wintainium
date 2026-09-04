# Phase 7A — Orchestration Input Boundary Contract

## Purpose

Phase 7A defines the Core-owned input boundary for an end-to-end Wintainium
operation. The boundary establishes the minimum application-management context
that orchestration may carry between the already-defined lifecycle stages.

The input boundary does not execute providers, download artifacts, verify
artifacts, select installers, install software, or mutate installed state.

## Input

`New-WintainiumOrchestrationRequest` accepts:

- `ManifestPath` — an absolute path to the application manifest that the
  orchestration operation will validate through the existing manifest/provider
  workflow;
- `MachineArchitecture` — the target machine architecture used by the locked
  Phase 4 update-target resolution boundary;
- `DownloadRoot` — an absolute Core-controlled root under which Phase 5 may
  publish a completed download.

The boundary does not require the manifest file or download directory to exist.
Those filesystem checks belong to the stage that owns the corresponding
resource operation.

## Request Shape

A successful request has:

- `IsValid = $true`;
- `Request.OperationId` — a new Core-generated orchestration correlation
  identifier;
- `Request.ManifestPath` — normalized to a full path;
- `Request.MachineArchitecture` — trimmed but otherwise preserved;
- `Request.DownloadRoot` — normalized to a full path;
- `Errors = @()`.

A failed request has `IsValid = $false`, `Request = $null`, and one or more
structured errors. The boundary does not throw for these expected input
validation failures.

## Path Boundary

`ManifestPath` and `DownloadRoot` must be fully qualified paths. Orchestration
must not depend on the caller's current working directory after a request has
been created.

The input boundary does not reinterpret a manifest, infer an application, or
select an alternate download destination. Later stages remain responsible for
their own domain-specific validation and safety checks.

## Correlation

The orchestration `OperationId` is the parent correlation identifier for the
future end-to-end operation. Stage-specific operations may retain their own
operation identifiers while preserving the orchestration correlation through
the orchestration context and structured results.

The input boundary does not replace the operation identifiers owned by Phases
3–6.

## Security Boundary

This boundary contains no executable instructions, provider commands, installer
commands, shell text, credentials, trust decisions, or artifact contents.

An accepted orchestration request does not establish that the manifest is
valid, that a provider is trustworthy, that an update exists, that a download
is safe, that an artifact is authentic or verified, or that installation is
approved.

## Phase Boundary

Phase 2 remains responsible for local manifest discovery and validation.
Phase 3 owns provider-backed release discovery. Phase 4 owns deterministic
update decisions. Phase 5 owns controlled artifact acquisition. Phase 6 owns
installer selection and controlled installation. Phase 7 owns sequencing and
propagation between those established boundaries.

The input boundary must remain a request-construction primitive rather than
becoming a second implementation of any downstream stage.
