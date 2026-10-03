# Public PowerShell Result Contract

This document describes the structured-result principles shared by the current
public Wintainium.Core operations.

## Common shape

Where applicable, public results expose:

- `OperationId` — Core-generated operation correlation;
- `IsSuccessful` or an operation-specific validity property;
- `Status` — documented operation status;
- operation-specific data;
- `Errors` — structured errors;
- `Warnings` — structured warnings;
- `LogEvents` — structured diagnostic events.

Collection-valued properties remain arrays, including when empty.

## Current operations

The current exported surface includes manifest discovery, installed-state
observation/reconciliation, reconciliation configuration, application
validation, release discovery, update-status observation, end-to-end update and first-install execution, onboarding, icon override management, and application removal.

The exact export list is authoritative in `core/Wintainium.Core/Wintainium.Core.psd1`
and `Wintainium.Core.psm1`.

## Update result

`Invoke-WintainiumApplicationUpdate` returns a presentation-neutral lifecycle
projection containing:

- `OperationId`
- `IsSuccessful`
- `WasCancelled`
- `Status`
- `ApplicationId`
- `Stages`
- `Errors`
- `Warnings`
- `LogEvents`
- `Error`
- `TroubleshootingDiagnostics` — failure-only execution breadcrumbs for diagnosing lifecycle failures; empty on successful or cancelled operations.

The public result also includes `TroubleshootingDiagnostics`, an empty array for successful or cancelled operations and a failure-only collection of concise execution breadcrumbs when the lifecycle fails. These diagnostics are intended for troubleshooting and do not alter lifecycle decisions or verification behavior.

The public result is not a pass-through of private lifecycle state.

## Install result

`Invoke-WintainiumApplicationInstall` returns the same presentation-neutral lifecycle projection used by the update execution boundary. Its lifecycle stages are shared with update execution; the decision stage establishes whether a deterministic installable release exists for an application whose authoritative state is `NotInstalled`.

## Update-status result

`Get-WintainiumApplicationUpdateStatus` exposes the observations needed by
presentation clients without exposing the internal update-decision composition.

It includes:

- `OperationId`
- `IsSuccessful`
- `Status`
- `Manifest`
- `InstalledState`
- `Decision`
- `Errors`
- `Warnings`
- `LogEvents`

The projected decision includes update availability, reason code/reason,
determinism, and selected release information when available.

## Onboarding result

`Invoke-WintainiumApplicationOnboarding` returns:

- `OperationId`
- `IsSuccessful`
- `Status`
- `SourceResolution`
- `ApplicationDefinition`
- `ManifestPath`
- `Errors`
- `Warnings`
- `LogEvents`

The result allows the desktop to distinguish unsupported, ambiguous,
unavailable, authentication-required, interactive, invalid, and successful
source-resolution outcomes without inspecting provider internals.

## Installed-state semantics

Managed installed state is explicitly one of:

- `Installed`
- `NotInstalled`
- `Unknown`

A missing managed record is `Unknown`. The presentation layer must not turn
absence of evidence into a claim of non-installation.

## Presentation boundary

Human-readable formatting belongs outside Core. A CLI or GUI may transform
structured data into text, cards, dialogs, lifecycle indicators, or other
visuals, but presentation must not change provider selection, update decisions,
verification requirements, installer selection, reconciliation semantics, or
cancellation behavior.

## Error handling

Clients should branch on documented machine-readable error codes/categories,
not on diagnostic message wording.

Parameter-binding errors and unexpected programmer errors may remain normal
PowerShell errors rather than operation-result failures.

## Correlation and cancellation

Core owns `OperationId`. Clients consume it and do not replace it.

Cancellation is an engine semantic. A presentation client may expose Cancel,
but it must route cancellation through the documented operation boundary rather
than killing arbitrary processes or inventing its own lifecycle semantics.
