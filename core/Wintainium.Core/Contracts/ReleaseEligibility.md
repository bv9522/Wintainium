# Phase 4C Release Eligibility Contract

## Purpose

Release eligibility converts provider release observations into a deterministic set of releases that are permitted to compete for update targeting.

It consumes validated Phase 4 inputs and the Phase 4B version-comparison contract. It does not select artifacts, download data, verify bytes, or install software.

## Eligibility Rules

A release is eligible only when all applicable policy and compatibility checks pass:

- The release channel is permitted by the manifest's `release.channel` policy.
- Stable policy does not admit prereleases unless the manifest explicitly permits them.
- A deprecated release is not eligible.
- If an installed architecture and release architecture are both known, they must be compatible.
- A release must not be selected as a downgrade.
- When installed and release versions are comparable, only a release greater than the installed version may compete for an update.
- An unknown version comparison does not establish eligibility.
- Missing or malformed provider metadata does not get guessed into eligibility.

## Channel Policy

`stable` admits stable releases only.

`prerelease` admits prerelease releases. A prerelease policy does not silently convert an unavailable or unknown channel into stable.

`any` admits both stable and prerelease releases.

Provider channel values are normalized before policy evaluation. Unknown channel values are treated as insufficient metadata rather than guessed.

## Architecture

Architecture compatibility is evaluated conservatively. Known incompatible architectures are rejected. Unknown architecture is not silently treated as compatible unless the manifest's artifact policy explicitly permits unknown architecture; artifact-level compatibility remains a separate Phase 4D concern.

## Result

Each release receives a structured eligibility observation containing:

- the original release object
- `Eligible` boolean
- deterministic `ReasonCode`
- human-readable `Reason`
- version comparison outcome where applicable

The operation also returns the eligible releases in deterministic input order. It does not select the final release target; final update determination remains a later Phase 4 stage.

## Phase Boundary

Phase 4C answers: `Is this discovered release allowed to compete?`

Phase 4D answers: `Which artifact belonging to an eligible release is compatible and preferred?`

Phase 4E/4F determine the final update decision and target. Downloading begins in Phase 5; installation begins in Phase 6.
