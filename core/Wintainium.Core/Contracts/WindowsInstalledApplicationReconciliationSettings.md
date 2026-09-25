# Windows Installed-Application Reconciliation Settings Contract

## Status

Phase 13A contract.

This document freezes the declarative settings boundary for the first production Windows installed-application reconciliation plugin:

`Wintainium.reconciliation.windows-installed-application`

The settings identify an application in Windows uninstall registration. They do not identify how the application obtains releases. Release discovery remains owned by the provider named by the manifest `source` reference. A provider may be a GitHub release provider, an official-download-page provider, or another future provider without changing this reconciliation contract.

## Boundary

```text
Application Manifest
       |
       | reconciliation.settings
       v
Windows Installed-Application Reconciler
       |
       | observational evidence
       v
Core Reconciliation Operation
       |
       v
InstalledApplicationState
```

The reconciler observes Windows state only. It does not discover releases, compare versions, select updates, download artifacts, install applications, or persist Wintainium state.

## Settings Shape

The plugin-specific settings object is:

```json
{
  "registry": {
    "locations": [
      {
        "scope": "machine",
        "view": "64"
      },
      {
        "scope": "machine",
        "view": "32"
      },
      {
        "scope": "user",
        "view": "native"
      }
    ],
    "match": [
      {
        "value": "DisplayName",
        "equals": "Example Application"
      }
    ]
  }
}
```

The application-manifest schema continues to treat `reconciliation.settings` as an opaque object. This contract belongs to the Windows reconciliation plugin and must not add Windows-specific semantics to generic Core manifest validation.

## Registry Domain

The initial implementation is deliberately restricted to Windows uninstall registration beneath:

`Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall`

Supported logical scopes are:

- `machine` — the local machine uninstall registration.
- `user` — the current user's uninstall registration.

Supported machine registry views are:

- `64` — 64-bit machine registry view.
- `32` — 32-bit machine registry view.

The current-user location uses `native` because the contract is describing the current user's logical registry view, not asserting application architecture.

The plugin must not accept arbitrary registry roots or paths through manifest settings. This is an installed-application reconciler, not a general-purpose registry reader.

## Identification

Identification is declarative and deterministic.

`registry.locations` declares the registry locations to inspect. `registry.match` declares exact value predicates that a candidate uninstall entry must satisfy.

The initial matchable registry values are:

- `subkey` — the uninstall entry's immediate subkey name.
- `DisplayName` — the registered application display name.
- `Publisher` — the registered publisher.

A candidate matches only when it satisfies every declared predicate.

String matching is exact and case-insensitive by default. The initial contract does not support substring matching, regular expressions, fuzzy matching, ranking, or heuristic similarity.

The reconciler must not use the manifest's human-readable `name` or `id` as an implicit registry search criterion. If a registry value is intended to identify the application, the manifest must declare that criterion explicitly.

## Candidate Cardinality

After evaluating all declared locations and predicates:

| Candidate count | Installation state |
| --- | --- |
| `0` | `NotInstalled` |
| `1` | `Installed` |
| `>1` | `Unknown` |

The reconciler must never resolve ambiguity by choosing the first candidate, preferring a registry view, preferring machine over user scope, or applying an undocumented heuristic.

A manifest can remove ambiguity by narrowing its declared locations or adding deterministic match predicates.

## Insufficient Evidence

`NotInstalled` means that the configured registry search completed successfully and produced zero matching candidates.

The following conditions must not be converted to `NotInstalled`:

- invalid or incomplete reconciliation settings;
- inability to inspect a required registry location;
- malformed registry data that prevents reliable evaluation;
- multiple matching candidates;
- any other condition in which the reconciler cannot establish either installed or not-installed state reliably.

Such conditions produce `Unknown` evidence when the reconciliation operation can return a valid observation, together with structured diagnostics describing the reason. Configuration errors that prevent the plugin from executing its contract produce a structured reconciliation failure according to the existing reconciliation result contract.

## Evidence Mapping

For a unique matching uninstall entry, the reconciler may return:

| Windows observation | Reconciliation evidence |
| --- | --- |
| Unique matching entry | `InstallationState = Installed` |
| `DisplayVersion` | `Version` |
| `DisplayVersion` provenance | `VersionSource = Registry` |
| `InstallLocation` | `InstallationLocation` |
| Reliable architecture observation | `Architecture` |
| Reliable channel observation | `Channel` |
| Registry source | `EvidenceSource = WindowsUninstallRegistry` |

Missing optional values remain absent or unknown. The reconciler must not invent architecture or channel from a registry view alone.

For zero candidates, the evidence reports `InstallationState = NotInstalled` and must not invent a version or installation location.

For ambiguous or otherwise insufficient evidence, the evidence reports `InstallationState = Unknown` when a structured observation can be returned.

## Version and Policy Boundary

`DisplayVersion` is copied as an opaque observation. The reconciler does not parse or compare versions.

Release discovery and update policy are independent of this contract. In particular, an application whose release source is GitHub and an application whose release source is an official download page use the same Windows reconciliation mechanism.

The complete lifecycle remains:

**Manifest describes → Provider discovers → Core decides → Download obtains → Verification establishes trust → Installer applies → Orchestration coordinates → UX presents.**

Installed-state reconciliation supplies an observation to that lifecycle; it does not become a second decision engine.

## Security and Authority

The plugin must:

- read only the declared uninstall-registration domain;
- perform no arbitrary registry traversal;
- execute no manifest-supplied commands or expressions;
- launch no installer or application;
- write no Wintainium managed-state files;
- avoid machine-wide software inventory behavior beyond the declared application-scoped search.

Core remains authoritative for accepting evidence, converting it to `InstalledApplicationState`, reconciling it with prior managed state, and persisting authoritative installed state.

## Genericity

The plugin contains no application-specific branches.

7-Zip is an initial integration subject only. The same plugin contract must be usable for Git, GIMP, HandBrake, and other Windows applications whose installed registration can be identified deterministically.

The release provider is orthogonal to reconciliation. GitHub releases and official download pages are upstream discovery mechanisms and do not require separate Windows reconciliation implementations.

## Phase Boundary

Phase 13A freezes this settings and behavior contract.

It does not implement registry enumeration, candidate matching, plugin registration, or production reconciliation behavior. Those belong to later Phase 13 sub-phases.
