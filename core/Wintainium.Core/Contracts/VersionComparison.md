# Version Comparison Contract

## Status

Phase 4B contract: Accepted.

## Purpose

Wintainium must compare upstream and installed version observations without assuming that every vendor uses SemVer or Windows `System.Version` semantics.

## Version Observation

A version observation preserves the original string exactly as supplied by its source and may carry a deterministic normalized comparison representation when one can be established.

The original value is never discarded or rewritten as the authoritative display value.

## Comparison Strategies

Core may recognize a version string using a deterministic strategy, including:

1. Semantic-version-compatible syntax, including prerelease identifiers and build metadata.
2. Windows/System.Version-compatible numeric version syntax.
3. Numeric component sequences commonly used by Windows software when a deterministic interpretation is unambiguous.
4. Opaque vendor-specific strings for which no safe structured interpretation can be established.

Recognition must be conservative. A string that could have multiple materially different interpretations must remain opaque rather than being guessed into a comparison scheme.

## Ordering

A comparison result is one of:

- `Less`
- `Equal`
- `Greater`
- `Unknown`

`Unknown` means Core cannot establish a deterministic ordering from the two observations. It is not equivalent to `Equal` and must never be silently treated as an available update or downgrade.

When two observations use incompatible comparison strategies, Core must not invent a cross-strategy ordering. A future architecture decision may add explicit conversion rules if required.

## Prerelease Handling

Prerelease identifiers are part of the version comparison representation. Whether a prerelease release is eligible for a particular application is a Phase 4C policy decision, not a responsibility of the version parser.

## Build Metadata

SemVer build metadata does not affect SemVer precedence. Other recognized numeric build/revision components are compared only according to the selected strategy's documented rules.

## Determinism and Explainability

Given identical version observations, Core must select the same strategy and produce the same normalized representation and comparison result. The result must expose enough information for later decision results and GUI explanations to identify the strategy and why ordering was or was not possible.

## Phase Boundary

Phase 4B defines normalization and comparison only. Release eligibility, artifact selection, update-decision status, downloading, verification, installation, and lifecycle orchestration belong to later phases.
