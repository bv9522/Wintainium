# Wintainium CLI Reference

## Scope

This document describes the current exported PowerShell surface. All exported
commands return structured data; they do not require callers to parse terminal
formatting.

The authoritative export list is the Core module manifest and
`Wintainium.Core.psm1`.

## Current exported commands

| Command | Purpose |
|---|---|
| `Get-WintainiumManifest` | Discover/import local application manifests |
| `Get-WintainiumApplicationInstalledState` | Read authoritative managed installed state |
| `Invoke-WintainiumApplicationReconciliation` | Refresh authoritative installed state from the declared reconciliation plugin |
| `Set-WintainiumApplicationReconciliationSettings` | Configure declared reconciliation-plugin settings |
| `Test-WintainiumApplicationDefinition` | Validate an application definition and resolve declared capabilities |
| `Get-WintainiumApplicationRelease` | Discover normalized upstream releases |
| `Get-WintainiumApplicationUpdateStatus` | Evaluate and expose structured update status without installing |
| `Invoke-WintainiumApplicationUpdate` | Execute the complete update lifecycle |
| `Invoke-WintainiumApplicationOnboarding` | Resolve a source URL, normalize an application definition, and persist it |
| `Set-WintainiumApplicationIconOverride` | Set or clear a user-selected application icon override |
| `Remove-WintainiumApplication` | Remove a managed application definition from the collection |

These are exported engine operations, not eleven unrelated UI features. The
desktop uses only the operations needed for its current presentation/client
contracts.

## Import and inspect

From the repository root:

```powershell
Import-Module .\core\Wintainium.Core\Wintainium.Core.psd1 -Force
Get-Command -Module Wintainium.Core
```

## Core lifecycle

The complete update command owns:

```
Manifest Validation
    → Release Discovery
    → Update Decision
    → Download
    → Verification
    → Installer Selection
    → Installation
    → Reconciliation
```

The caller supplies application-management inputs. Core owns lifecycle
composition, provider interaction, artifact acquisition, verification,
installer invocation, reconciliation, cancellation, and managed state.

## Important state semantics

A missing managed installed-state record is **Unknown**, not automatically
**NotInstalled**.

An application that is known to be uninstalled may legitimately have
`NotInstalled` state when authoritative reconciliation or application
management establishes that fact. The desktop must distinguish that from an
unknown observation.

## Onboarding

`Invoke-WintainiumApplicationOnboarding` is the Core boundary used by the
Dashboard's Add Software flow.

Input:

- `SourceUri`
- `ManifestRoot`
- optional Core-owned plugin/schema inputs

Core resolves source providers, handles ambiguity, resolves the default
application policy, normalizes the application definition, and persists a
manifest only after successful resolution/normalization.

The desktop does not construct or persist the manifest itself.

## Update status

`Get-WintainiumApplicationUpdateStatus` evaluates manifest validity, release
discovery, authoritative installed state, and the Core update-decision pipeline.
It does not download, verify, install, or reconcile.

This command exists so presentation clients can display update state without
reimplementing update decisions.

## Icon overrides

`Set-WintainiumApplicationIconOverride` stores only the user-selected
override. Automatic icon metadata remains available and can be restored by
clearing the override.

## Removal

`Remove-WintainiumApplication` removes a recognized Wintainium manifest from
the configured collection root. It does not uninstall the Windows application.

## Structured results

Use documented properties and stable error codes:

```powershell
$result.IsSuccessful
$result.Status
$result.Errors | Select-Object Code, Message
$result.Warnings
$result.LogEvents
```

Do not branch on formatted messages, colors, progress text, or console output.

## See also

- `docs/GettingStarted.md`
- `docs/ManifestAuthoring.md`
- `docs/PublicPowerShellContract.md`
- `docs/PublicResultContract.md`
- `docs/ApplicationOnboardingContract.md`
- `docs/PublicApplicationUpdateResult.md`
