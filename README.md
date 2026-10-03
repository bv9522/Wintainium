# Wintainium

Wintainium is an open, modular Windows software manager inspired by Obtainium.
It discovers applications from upstream sources, determines whether updates are
needed, acquires and verifies artifacts, installs them through pluggable
installers, and reconciles authoritative installed state.

Wintainium is now a **PowerShell Core engine with a WinUI 3 desktop client**.
The desktop presents the engine; it does not become a second lifecycle engine.

## Current status

**Phase 14 — GUI Productization is in progress.**

The Core lifecycle is production-proven through a real 7-Zip update:
manifest validation → release discovery → update decision → download →
verification → installer selection → native installer execution/elevation →
post-install reconciliation → authoritative installed-state refresh.

Phase 13.5 production packaging is complete. The desktop client now provides
the Dashboard/application collection, Add Software onboarding, application
Details, release/update presentation, operation diagnostics, automatic/custom
application icons, and Remove Software from the Wintainium collection.

The current Phase 14 work is productization rather than proving the underlying
lifecycle. Remaining work is concentrated on onboarding polish, the update
experience, settings productization, visual refinement, accessibility and
interaction auditing, and final integration/lock.

## Architecture

The governing boundaries are:

> **Manifest describes. Provider discovers. Core decides. Download obtains.
> Verification establishes trust. Installer applies. Orchestration coordinates.
> UX presents.**

And:

> **The interface presents the engine; it does not become the engine.**

PowerShell Core remains authoritative for lifecycle, policy, provider,
installer, verification, reconciliation, cancellation, and managed installed
state. WinUI consumes documented structured results through the C# adapter and
presentation/application services.

The architecture deliberately does not pretend that a native installer has a
Wintainium-owned progress bar. Wintainium reports its own lifecycle activity
before and after native installer execution and reconciles authoritative state
afterward.

## Production capabilities

- GitHub Releases source provider
- Official download-page source provider
- EXE, MSI, portable ZIP, and MSIX installer plugins
- Windows installed-application reconciliation
- Mandatory artifact verification
- Authoritative managed installed-state persistence
- Source URL application onboarding
- Structured update status and end-to-end update execution
- User-selectable application icon overrides while preserving automatic icon discovery
- Removal of an application from the Wintainium collection without conflating it with uninstalling Windows software
- WinUI 3 Dashboard and Application Details presentation

## Repository map

- `core/` — PowerShell engine and public contracts
- `src/Wintainium.Desktop/` — WinUI 3 desktop client
- `plugins/` — provider, installer, and reconciliation plugins
- `manifests/` — application definitions
- `schemas/` — authoritative JSON Schemas
- `tests/` — automated regression coverage
- `docs/` — user, architecture, contract, and development documentation

## Documentation

- [Getting Started](docs/GettingStarted.md)
- [CLI Reference](docs/CLI.md)
- [Manifest Authoring](docs/ManifestAuthoring.md)
- [Architecture](ARCHITECTURE.md)
- [Project Charter](PROJECT.md)
- [Roadmap](ROADMAP.md)
- [Development Guidelines](docs/DEVELOPMENT.md)
- [Application Onboarding Contract](docs/ApplicationOnboardingContract.md)
- [Public PowerShell Contract](docs/PublicPowerShellContract.md)
- [Release Packaging](docs/ReleasePackaging.md)

## Desktop development

The production desktop project is under `src/Wintainium.Desktop`.

Release build:

```powershell
dotnet build .\src\Wintainium.Desktop\Wintainium.Desktop.csproj -c Release
```

The desktop targets .NET 10 / WinUI 3 and hosts Wintainium.Core in-process
through Microsoft.PowerShell.SDK. The GUI must not call private Core functions,
providers, installers, or orchestration stages directly.

## Current direction

Phase 14 is the final major productization phase before durable application
lifecycle work. The roadmap then moves through persistent application lifecycle,
plugin ecosystem/extensibility, reliability/security/recovery, and release
engineering toward Wintainium 1.0.
