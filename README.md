# Wintainium

Wintainium is an open, modular Windows software manager inspired by Obtainium.
It helps users install and update applications from official upstream sources
such as GitHub Releases and vendor download pages.

The PowerShell engine is the primary product. A future C# GUI will call the
engine rather than contain its own package-management logic.

## Status

Phases 1–13.5 are implemented through the current production installer/reconciliation architecture. Phase 13.5 is in final real-application validation; Phase 14 GUI productization is in progress.

The current public PowerShell surface consists of six commands:
`Get-WintainiumManifest`, `Get-WintainiumApplicationInstalledState`,
`Test-WintainiumApplicationDefinition`, `Get-WintainiumApplicationRelease`,
`Invoke-WintainiumApplicationUpdate`, and
`Invoke-WintainiumApplicationOnboarding`.

The public update command is a presentation-neutral boundary over the complete
Core-owned lifecycle. Callers supply documented application inputs; Core owns
orchestration, provider interaction, download and verification, installer
execution, reconciliation, cancellation, and managed installed-state
persistence.

## Repository map

- `docs/` — design, CLI, user, and contributor documentation.
- `core/` — PowerShell engine module.
- `plugins/` — independently loadable source and installer plugins.
- `manifests/` — application definitions in JSON.
- `schemas/` — authoritative JSON Schemas.
- `tests/` — automated tests.

## User documentation

- [`docs/GettingStarted.md`](docs/GettingStarted.md) — first-use walkthrough.
- [`docs/CLI.md`](docs/CLI.md) — current public command reference.
- [`docs/ManifestAuthoring.md`](docs/ManifestAuthoring.md) — manifest fields,
  policies, examples, and validation guidance.
- [`docs/Diagnostics.md`](docs/Diagnostics.md) — structured errors, operation
  correlation, and troubleshooting guidance.
- [`docs/InstallerContract.md`](docs/InstallerContract.md) — production installer
  capabilities, selection boundaries, invocation rules, and security limits.
- [`docs/PublicApplicationUpdateResult.md`](docs/PublicApplicationUpdateResult.md) —
  public update result contract.

## Developer and architecture documentation

See [PROJECT.md](PROJECT.md), [ROADMAP.md](ROADMAP.md), and
[ARCHITECTURE.md](ARCHITECTURE.md) for the current direction. Contributor and
contract documentation lives under `docs/`.

The production plugin set currently includes GitHub Releases and official
download-page providers, four installer implementations (EXE, MSI, portable
ZIP, and MSIX), and the Windows installed-application reconciliation plugin.
Installer selection, artifact selection, verification, reconciliation, and
lifecycle policy remain Core-owned boundaries; the desktop client presents
those results rather than implementing them.
