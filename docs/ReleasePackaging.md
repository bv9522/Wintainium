# Release Packaging

## Purpose

This document defines the Phase 8 release boundary for Wintainium. It is the
source-of-truth for what a distributable source package must contain while the
project is still using the PowerShell engine as its primary product.

The release boundary is deliberately deterministic: a release is assembled
from repository files, with no generated development state, test output, local
configuration, or working-directory artifacts included.

## Authoritative version

The Wintainium Core module manifest is the authoritative version source for
the current release boundary:

`core/Wintainium.Core/Wintainium.Core.psd1` → `ModuleVersion`

For the current Phase 8 development line, the version is `0.1.0`.

A release process must read the version from the module manifest rather than
maintaining a second independent application-version value. If a future
release format requires additional version metadata, it must be derived from
this value or explicitly supersede it through a documented contract change.

## Required release contents

A source release package must preserve these repository paths and their
relative layout:

- `core/Wintainium.Core/` — the PowerShell engine and its internal contracts.
- `schemas/` — authoritative application-definition schemas.
- `plugins/` — plugin implementations and plugin layout required by the
  release. Empty development placeholder directories are not release
  dependencies.
- `manifests/` — application manifests shipped with the release, when any are
  present.
- `docs/` — user, architecture, contract, and contributor documentation that
  describes the shipped engine.
- `README.md` — project entry point and public-surface overview.
- `PROJECT.md` — project charter and scope.
- `ARCHITECTURE.md` — current architecture boundary.
- `ROADMAP.md` — project roadmap.
- `CHANGELOG.md` — release history.

The Core module manifest and module file are mandatory members of the Core
package boundary even when the package is assembled from a larger repository
checkout.

## Excluded development material

The following must not be copied into a distributable release package:

- `.git/`
- `.github/`
- `tests/`
- local editor or IDE state
- Pester output, coverage output, and temporary test artifacts
- generated build directories not explicitly defined by a release contract
- local user configuration, caches, logs, and temporary download/install data
- empty repository placeholders whose only purpose is to preserve a directory
  during development

Exclusion is based on package purpose, not on whether a file happens to be
textual. Tests and development automation remain part of the source
repository but are not runtime package assets.

## Validation boundary

Before a release is accepted, validation must establish all of the following:

1. The Core module manifest exists and can be parsed as PowerShell data.
2. `ModuleVersion` is present and is a valid release version.
3. The Core module file referenced by `RootModule` exists.
4. The manifest's exported public command surface is the supported surface.
5. The authoritative application-manifest schema exists.
6. Required documentation assets exist.
7. Repository development material is not included in the release payload.
8. The package preserves the documented relative layout.

This validation checks release completeness; it does not install software,
execute plugins, contact upstream providers, or mutate user state.

## Package shape

The intended source-release layout is:

```text
Wintainium/
├── ARCHITECTURE.md
├── CHANGELOG.md
├── PROJECT.md
├── README.md
├── ROADMAP.md
├── core/
│   └── Wintainium.Core/
├── docs/
├── manifests/
├── plugins/
└── schemas/
```

`tests/` and repository metadata may remain present in a source checkout but
are outside this distributable package shape.

## Future release tooling

A later packaging implementation may materialize this boundary as a
repeatable archive/build command. Such tooling must consume the authoritative
version and this documented file boundary rather than embedding a second,
independent list of runtime behavior or inventing package-time configuration.

Installer/upgrade behavior is intentionally outside this document. Phase 8E
will define which user-owned state is preserved or replaced during an actual
upgrade.
