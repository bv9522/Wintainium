# Phase 4C Release Eligibility Contract

## Purpose

Release eligibility converts provider release observations into a deterministic set of releases that are permitted to compete for update targeting.

It consumes validated Phase 4 inputs and the Phase 4B version-comparison contract. It does not select artifacts, download data, verify bytes, or install software.

## Eligibility Rules

A release is eligible only when all applicable policy checks pass:

- The release channel is permitted by the manifest's `release.channel` policy.
- Stable policy admits stable releases only.
- Prerelease policy admits prerelease releases only.
- `any` admits both stable and prerelease releases.
- A deprecated release is not eligible when the provider explicitly marks it deprecated.
- When installed and release versions are comparable, only a release greater than the installed version may compete for an update.
- Equal versions are not updates.
- Lower versions are never selected as downgrades.
- Unknown or incompatible version comparisons do not establish eligibility.
- Missing or malformed release metadata does not get guessed into eligibility.

## Channel Policy

`stable` admits stable releases only.

`prerelease` admits prerelease releases only. It does not silently convert an unknown channel into stable.

`any` admits both stable and prerelease releases.

Provider channel values are normalized before policy evaluation. Unknown channel values are treated as insufficient metadata rather than guessed.

## Release State

Provider metadata remains untrusted source metadata. A provider-supplied deprecation marker may be used as a release eligibility input, but it is not a trust decision and does not authorize execution of the release.

## Result

Each release receives a structured eligibility observation containing:

- the original release object
- `Eligible` boolean
- deterministic `ReasonCode`
- human-readable `Reason`
- version comparison outcome where applicable

The collection operation returns eligible releases in deterministic input order while retaining all observations, including rejected releases. It does not select the final release target; final update determination remains a later Phase 4 stage.

## Phase Boundary

Phase 4C answers: `Is this discovered release allowed to compete?`

Phase 4D answers: `Which artifact belonging to an eligible release is compatible and preferred?`

Phase 4E/4F determine the final update decision and target. Downloading begins in Phase 5; installation begins in Phase 6.
