# Wintainium

Wintainium is an open, modular Windows software manager inspired by Obtainium.
It helps users install and update applications from official upstream sources
such as GitHub Releases and vendor download pages.

The PowerShell engine is the primary product. A future C# GUI will call the
engine rather than contain its own package-management logic.

## Status

Phases 1–5 are implemented, tested, and locked. The current engine can validate
application manifests, discover upstream releases through provider plugins,
produce deterministic update decisions, and safely acquire the selected
artifact through the Core-owned download boundary.

Artifact verification, installer selection, installation, and end-to-end
lifecycle orchestration remain future phases.

## Repository map

- `docs/` — design, architecture, and contributor documentation.
- `core/` — the Wintainium PowerShell engine and its contracts.
- `plugins/` — independently loadable source and installer plugins.
- `manifests/` — application definitions in JSON.
- `tests/` — automated Pester tests.

See [PROJECT.md](PROJECT.md), [ROADMAP.md](ROADMAP.md), and
[ARCHITECTURE.md](ARCHITECTURE.md) for the project direction. See
[docs/Phase5DownloadEngine.md](docs/Phase5DownloadEngine.md) for the locked
Phase 5 acquisition boundary.
