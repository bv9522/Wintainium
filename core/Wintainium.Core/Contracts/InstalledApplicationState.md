# Installed Application State Contract

## Status

Phase 4A.1 contract: Proposed for implementation.

This contract defines the Core representation of the currently installed state
of one Wintainium-managed application. It is an input to later Phase 4 update
decision processing.

## Purpose

`InstalledApplicationState` represents application state already known to
Wintainium. It is intentionally independent of the mechanism that discovered
the state.

The contract does **not** define a Windows-wide inventory subsystem. Registry,
MSI, AppX/MSIX, portable-application, installer-specific, and future inventory
mechanisms may populate this Core representation through separate
implementations.

## Boundary

```text
Application Identity / Manifest
            +
  Inventory or State Source
            |
            v
InstalledApplicationState
            |
            v
       Phase 4 Core
```

The state model contains observations about the installed application. It does
not make update decisions, compare versions, invoke providers, download
artifacts, verify downloaded bytes, or install software.

## Core Model

The conceptual model is:

| Property | Required | Meaning |
| --- | --- | --- |
| `ApplicationId` | Yes | Stable Wintainium application identity corresponding to the manifest `Id`. |
| `InstallationState` | Yes | Normalized current state: `Installed`, `NotInstalled`, or `Unknown`. |
| `Version` | No | Installed version as reported by the state source. It remains an opaque string at this boundary. |
| `VersionSource` | No | Descriptive indication of where the reported version came from. |
| `Architecture` | No | Known installed architecture, or `unknown` when it cannot be determined. |
| `Channel` | No | Known installed release channel, or `unknown` when it cannot be determined. |
| `InstallationLocation` | No | Known installation location, when supplied by the state source. |

Optional properties represent unavailable observations. Unknown must not be
silently converted into a known value.

## Application Identity

`ApplicationId` uses the same stable Wintainium application identity as the
manifest model. The installed-state contract does not introduce a second
application identity or require provider-specific identifiers.

Inventory mechanisms may maintain their own source-specific identifiers
internally, but those identifiers do not replace `ApplicationId` in the Core
contract.

## Installation State

`InstallationState` has three Phase 4A values:

- `Installed` — the state source has established that the application is installed.
- `NotInstalled` — the state source has established that the application is not installed.
- `Unknown` — the state source cannot establish either condition reliably.

An `Installed` state does not require every optional property to be known. For
example, an installed portable application may have an unknown channel or
architecture.

A `NotInstalled` state normally has no installed version. Core must not invent
a version for an application that is not installed.

## Version

`Version` is the raw version observation from the state source.

Phase 4A deliberately does not assign a versioning scheme to this value. A
source may report semantic versions, Windows-style versions, vendor-specific
strings, build identifiers, or other forms.

Normalization and comparison belong to Phase 4B.

The installed-state contract therefore must not require a SemVer parser or
perform comparison as part of state creation.

## Version Source

`VersionSource` is descriptive provenance for the observed version. It is not
an executable provider or inventory instruction.

Examples include `Registry`, `Msi`, `Appx`, `Installer`, `Portable`, or
`Unknown`. The initial implementation should preserve the source value without
requiring a complete inventory-provider taxonomy.

## Architecture

`Architecture` records the architecture associated with the installed
application when known.

The Phase 4 Core representation uses the following conceptual values:

- `x86`
- `x64`
- `arm64`
- `neutral`
- `unknown`

`unknown` means that the state source could not establish the architecture. It
must not be interpreted as compatible with every architecture merely because
it is unknown.

Provider and manifest representations may use source-specific or previously
established vocabulary at their boundaries. Any required normalization between
those representations belongs to the appropriate Core decision/normalization
step rather than to the inventory source.

## Channel

`Channel` records the installed release channel only when it is known.

The conceptual values are:

- `stable`
- `prerelease`
- `unknown`

An unknown installed channel must not be silently treated as stable. Channel
policy and release eligibility are evaluated later in Phase 4.

## Installation Location

`InstallationLocation` is optional observational state. Its presence does not
authorize Core or any plugin to execute files from that location.

The property exists so future lifecycle and installer phases can consume known
installation state without requiring them to rediscover it through unrelated
mechanisms.

## Source Independence

The contract deliberately does not identify a particular inventory mechanism.
Future implementations may obtain state from:

- Windows uninstall/registry information
- MSI information
- AppX/MSIX information
- installer-specific records
- portable application records
- future inventory providers

Those mechanisms must translate their observations into the Core contract
rather than introducing source-specific branches into update-decision logic.

## Security and Trust

Installed application state is an observation, not a trust decision.

The presence of an installation location, version, architecture, or other
state must not by itself cause Core to execute a file, trust provider metadata,
or bypass later safety policy.

## Phase Boundary

Phase 4A establishes the representation of installed application state.

It does not establish:

- Windows-wide software inventory
- version normalization or comparison
- release eligibility
- artifact selection
- update decisions
- provider invocation
- downloading
- downloaded-byte verification
- installation
- lifecycle orchestration

Phase 4B will define version normalization and comparison. Later Phase 4
sub-phases will consume this state when making deterministic update decisions.
