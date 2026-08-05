# Wintainium

Wintainium is an open, modular Windows software manager inspired by Obtainium.
It helps users install and update applications from official upstream sources
such as GitHub Releases and vendor download pages.

The PowerShell engine is the primary product. A future C# GUI will call the
engine rather than contain its own package-management logic.

## Status

Project foundation established; no application functionality is implemented.

## Repository map

- `docs/` — design and contributor documentation.
- `core/` — engine PowerShell module(s), once implementation begins.
- `plugins/` — independently loadable source and installer plugins.
- `manifests/` — application definitions in JSON.
- `tests/` — automated tests.

See [PROJECT.md](PROJECT.md), [ROADMAP.md](ROADMAP.md), and
[ARCHITECTURE.md](ARCHITECTURE.md) for the initial direction.
