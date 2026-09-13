# Wintainium

Wintainium is an open, modular Windows software manager inspired by Obtainium.
It helps users install and update applications from official upstream sources
such as GitHub Releases and vendor download pages.

The PowerShell engine is the primary product. A future C# GUI will call the
engine rather than contain its own package-management logic.

## Status

Phases 1–6 are implemented, tested, and locked. Phase 7 orchestration 7A–7I
is implemented, validated, and locked through the Core-owned lifecycle
coordination boundary. Phase 8A is complete; Phase 8B is refining the public
CLI/result boundary and beginning the user-facing documentation set.

The current public PowerShell surface intentionally consists of three commands:
`Get-WintainiumManifest`, `Test-WintainiumApplicationDefinition`, and
`Get-WintainiumApplicationRelease`. The complete update lifecycle remains an
internal engine capability until the authoritative installed-state and Core
composition boundaries are established.

## Repository map

- `docs/` — design, CLI, and contributor documentation.
- `core/` — PowerShell engine module.
- `plugins/` — independently loadable source and installer plugins.
- `manifests/` — application definitions in JSON.
- `tests/` — automated tests.

## CLI reference

See [`docs/CLI.md`](docs/CLI.md) for the current public command reference,
structured result handling, error handling, JSON serialization, and the limits
of the current update surface.

See [PROJECT.md](PROJECT.md), [ROADMAP.md](ROADMAP.md), and
[ARCHITECTURE.md](ARCHITECTURE.md) for the current direction.
