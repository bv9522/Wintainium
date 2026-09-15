# Wintainium Release Packaging

## Purpose

Phase 8D defines the release boundary for a distributable Wintainium source package. The package is assembled from repository runtime and documentation assets while development-only material remains outside the distributable boundary.

The release package is deterministic in **contents and relative layout**: the same repository state produces the same selected files and package structure. The ZIP archive itself is not required to be byte-for-byte identical across builds because archive metadata such as timestamps may vary.

Release packaging does not introduce application execution, installation, persistence, or upgrade behavior. Those concerns remain separate engine and Phase 8E responsibilities.

## Authoritative version source

The Core module manifest is the authoritative version source:

```text
core/Wintainium.Core/Wintainium.Core.psd1
```

Its `ModuleVersion` value determines the release package name. The current repository version is `0.1.0`.

No second release-version source is maintained by the packaging tools.

## Package boundary

The distributable package has this root layout:

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

The package preserves the contents and relative paths of these runtime/documentation boundaries:

- `core/` — Core engine module and its runtime contract/implementation files.
- `docs/` — user-facing and developer-facing documentation required by the supported implementation boundary.
- `manifests/` — shipped application manifests when present.
- `plugins/` — shipped plugin implementations when present.
- `schemas/` — runtime schemas required by the engine.

Repository placeholder files such as `.gitkeep` are not release dependencies and are omitted.

## Required release assets

A valid package must contain:

- `README.md`
- `PROJECT.md`
- `ARCHITECTURE.md`
- `ROADMAP.md`
- `CHANGELOG.md`
- `docs/GettingStarted.md`
- `docs/CLI.md`
- `docs/ManifestAuthoring.md`
- `docs/Diagnostics.md`
- `docs/PublicResultContract.md`
- `docs/PublicPowerShellContract.md`
- `docs/ReleasePackaging.md`
- `core/Wintainium.Core/Wintainium.Core.psd1`
- `core/Wintainium.Core/Wintainium.Core.psm1`
- `schemas/application-manifest.schema.json`

The Core manifest must declare the supported three-command public surface:

- `Get-WintainiumManifest`
- `Test-WintainiumApplicationDefinition`
- `Get-WintainiumApplicationRelease`

## Excluded development material

The distributable package must not contain:

- `.git/`
- `.github/`
- `tests/`
- `tools/`
- `.editorconfig`
- `.gitignore`
- `AI_CONTEXT.md`
- Pester output, coverage data, temporary test artifacts, or local build output.
- local user configuration, application state, caches, logs, temporary download data, or installation data.

Development tooling remains in the repository and is intentionally outside the release package.

## Release validation

`tools/Test-WintainiumReleasePackage.ps1` validates an assembled package independently of the builder. Validation establishes:

1. Required root files exist.
2. Required runtime directories exist.
3. No unexpected root-level repository or development entries are present.
4. Required documentation and runtime assets exist.
5. The Core module manifest parses successfully.
6. `ModuleVersion` exists and follows the supported version format.
7. The declared `RootModule` exists.
8. The exported public command surface matches the supported contract exactly.

Validation does not install software, execute application-management stages, contact upstream providers, or mutate user state.

## Package assembly

`tools/New-WintainiumReleasePackage.ps1` is repository tooling, not distributable runtime code. It:

1. Resolves the repository root.
2. Preflights required source files and directories before creating any package output.
3. Reads the authoritative Core `ModuleVersion`.
4. Creates `Wintainium-<version>/` under the requested output root.
5. Copies only the documented root files and package-boundary directories.
6. Excludes `.gitkeep` repository placeholders and development material by construction.
7. Validates the assembled package with the independent release validator.
8. Creates `Wintainium-<version>.zip` only after validation succeeds.
9. Refuses to overwrite an existing package directory or archive.
10. Removes partially assembled package output if a post-creation failure occurs.

File selection within each package-boundary directory is sorted by full source path before copying so that the selected file set and traversal order are stable.

The builder does not modify repository source files.

## Release archive determinism

The release contract is deterministic at the **file-selection and layout level**. It does not currently promise identical ZIP bytes across separate builds because standard archive creation may encode build-time metadata.

If byte-for-byte reproducible archives become a release requirement, archive metadata normalization will be introduced as an explicit future packaging enhancement rather than being implied by the current contract.

## Upgrade boundary

Release packaging does not define replacement or preservation of installed application state. Safe upgrade behavior, authoritative installed-application state, user configuration, persistence, and the supported N→N+1 upgrade path are Phase 8E responsibilities.
