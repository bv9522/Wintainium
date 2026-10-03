# Public PowerShell Contract

## Status

**Current and implemented.**

Wintainium.Core exposes structured public operations for manifest management,
installed-state observation/reconciliation, release discovery, update status,
end-to-end updates and first-install execution, source onboarding, icon overrides, and collection removal.

The public PowerShell layer is the engine boundary. Presentation clients consume
its documented semantic results; they do not call private Core functions or
construct lifecycle internals.

## Current exported surface

| Command | Role |
|---|---|
| `Get-WintainiumManifest` | Local manifest discovery/import |
| `Get-WintainiumApplicationInstalledState` | Read authoritative managed installed state |
| `Invoke-WintainiumApplicationReconciliation` | Refresh authoritative installed state |
| `Set-WintainiumApplicationReconciliationSettings` | Persist settings for a declared reconciliation capability |
| `Test-WintainiumApplicationDefinition` | Validate a manifest and resolve declared capabilities |
| `Get-WintainiumApplicationRelease` | Provider-backed release discovery |
| `Get-WintainiumApplicationUpdateStatus` | Read Core-owned update decision/status without executing an update |
| `Invoke-WintainiumApplicationUpdate` | Execute the complete Core-owned update lifecycle |
| `Invoke-WintainiumApplicationInstall` | Execute the complete Core-owned first-install lifecycle |
| `Invoke-WintainiumApplicationOnboarding` | Resolve a source URL, normalize an application definition, and persist it |
| `Set-WintainiumApplicationIconOverride` | Set/clear a user-selected icon override |
| `Remove-WintainiumApplication` | Remove a managed application definition from its collection |

The module manifest and `Wintainium.Core.psm1` export list are authoritative.
Older documentation that describes a four-command or seven-command surface is
historical and must not be used as the current API description.

## Architectural boundary

The public API deliberately hides:

- provider-specific request construction
- download requests
- verification internals
- installer requests
- reconciliation requests
- orchestration stage factories/plans
- cancellation contexts
- private filesystem/process helpers

Core owns lifecycle policy and traversal:

```
Manifest Validation
→ Release Discovery
→ Lifecycle Decision
→ Download
→ Verification
→ Installer Selection
→ Installation
→ Reconciliation
```

A presentation client may render these concepts when Core exposes suitable
structured state, but it does not decide which stages run or how success is
established.

## Update status versus update execution

`Get-WintainiumApplicationUpdateStatus` is observational. It validates the
application, discovers releases, reads authoritative installed state, and
projects the Core update decision.

It does **not** download, verify, install, or reconcile.

`Invoke-WintainiumApplicationUpdate` is the execution boundary for the
complete update lifecycle.

`Invoke-WintainiumApplicationInstall` is the execution boundary for the
complete first-install lifecycle. It uses the same shared execution stages and
installer/reconciliation boundaries, with an installation decision appropriate
for an application that is not installed.

## Onboarding boundary

`Invoke-WintainiumApplicationOnboarding` accepts an HTTP/HTTPS source URI and
an application-definition collection root. Core owns:

1. source URI validation;
2. source-resolution provider discovery and selection;
3. unsupported, unavailable, ambiguous, authentication, and interactive
   outcomes;
4. default application-policy resolution;
5. application normalization;
6. manifest persistence;
7. operation correlation and structured diagnostics.

The desktop only presents these results and supplies user interaction.

## Installed-state semantics

Wintainium-managed installed state is not a general Windows inventory.

- `Installed` means authoritative evidence establishes installation.
- `NotInstalled` means authoritative application state establishes that fact.
- `Unknown` means the available evidence is insufficient.

A missing managed record is **Unknown**. Clients must not silently reinterpret
Unknown as NotInstalled.

## Icon override boundary

`Set-WintainiumApplicationIconOverride` persists only the user override.
Automatic/provider-discovered icon metadata remains separate. Clearing the
override restores automatic icon behavior.

## Removal boundary

`Remove-WintainiumApplication` removes a recognized managed manifest from the
configured collection root. It does not uninstall the Windows application.

## Result rules

Public operations return structured objects. Clients should use:

- `OperationId` for Core-generated correlation;
- `IsSuccessful` or `IsValid` as applicable;
- documented `Status` values;
- structured operation data;
- `Errors`, `Warnings`, and `LogEvents`.

Clients must not parse console formatting or human-readable diagnostic text as
an API.

## Security and trust

Artifact verification remains mandatory before installation. A successful
download does not establish trust.

The source/discovery layer may broaden legitimate evidence discovery, including
provider-specific artifact metadata, but the verification boundary never lowers
its trust requirement merely because a source page lacks directly embedded
digest evidence.

## Presentation seam

The WinUI desktop is a client of this same boundary. It hosts PowerShell Core
in-process through Microsoft.PowerShell.SDK, but PowerShell SDK types do not
escape the adapter boundary.

The governing rule is:

> **The interface presents the engine; it does not become the engine.**
