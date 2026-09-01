# Phase 4E/4F Update Target Resolution Support Contract

## Purpose

This support contract composes the completed Phase 4C release-eligibility
result with the completed Phase 4D artifact selector. It resolves the single best update target:
an eligible release with one selectable artifact.

It is deliberately not the final update-decision result. Phase 4E defines that
result; the Phase 4F engine presents the resolved target, or the absence of
one, as the structured decision consumed by later orchestration.

## Inputs

- `EligibleReleases` — releases admitted by Phase 4C, in provider input order.
- `Manifest` — the validated manifest used by the Phase 4D selector.
- `MachineArchitecture` — the normalized target-machine architecture used by
  the Phase 4D selector.

Provider release and artifact data remain untrusted observations. This stage
does not invoke a provider, access the network, download bytes, verify hashes or
signatures, choose an installer, or execute anything.

## Target Selection Policy

For every eligible release, Phase 4E runs Phase 4D artifact selection and
retains that result as an observation.

A release can compete only when Phase 4D returns a selected artifact. Among
those candidates, Phase 4E selects:

1. the greatest deterministically comparable release version;
2. the first provider input occurrence when versions are equal.

The selected artifact is exactly the artifact selected by Phase 4D. Phase 4E
does not reinterpret artifact format, architecture, URI, hash, signature, or
filename metadata.

An unknown or incompatible version comparison between selectable candidates is
not resolved by guessing. In that condition no target is returned and the
result identifies `VersionRankingUnknown`.

## Result

The result contains:

- `SelectedRelease` — the selected release, or `$null`.
- `SelectedArtifact` — the selected artifact from that release, or `$null`.
- `Observations` — one observation per Phase 4C-eligible release, including
  its Phase 4D artifact-selection result and whether it was selectable.
- `ReasonCode` — `TargetSelected`, `NoSelectableArtifact`, or
  `VersionRankingUnknown`.
- `Reason` — a human-readable explanation.
- `IsDeterministic` — `true` only when a target result can be established
  without guessed ordering.

## Phase Boundary

Target resolution answers: `Which eligible release and artifact form the best update target?`

Phase 4E defines the final structured decision, and Phase 4F produces it.
Downloading begins in Phase 5; installation begins in Phase 6.
