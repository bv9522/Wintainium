# Phase 4D Artifact Eligibility and Selection Contract

## Purpose

Phase 4D determines which artifact candidates belonging to an eligible release are compatible with the manifest and target machine, then selects one artifact deterministically.

## Inputs

- `Release` — an eligible normalized Wintainium release.
- `Manifest` — the validated application manifest, including artifact format and architecture policy.
- `MachineArchitecture` — the normalized target machine architecture supplied by Core.

Provider-specific artifact metadata remains untrusted source metadata. Phase 4D does not download, execute, or verify artifact bytes.

## Eligibility Rules

An artifact is eligible only when all applicable checks pass:

- Its normalized format is present in `Manifest.artifact.formats`.
- Its normalized architecture is compatible with `MachineArchitecture`.
- An exact architecture match is compatible.
- `neutral` is compatible with every known machine architecture.
- `unknown` is not compatible unless `Manifest.artifact.allowUnknownArchitecture` is explicitly `true`.
- An unknown machine architecture does not establish compatibility with a machine-specific artifact.
- Missing or malformed artifact metadata is not guessed into eligibility.

Artifact URI, filename, size, hashes, and signature metadata are observations only. Their presence does not establish trust or authorize execution.

## Selection Policy

After eligibility filtering, selection is deterministic:

1. Prefer an exact machine-architecture artifact over `neutral` or explicitly allowed `unknown` architecture.
2. Prefer artifact formats according to the order declared by `Manifest.artifact.formats`.
3. Preserve original release artifact order as the final tie-breaker.

No network access, download, signature verification, installer invocation, or provider callback occurs during selection.

## Result

Each artifact receives a structured observation containing:

- the original artifact object
- `Eligible` boolean
- deterministic `ReasonCode`
- human-readable `Reason`
- normalized format and architecture where available

Selection returns:

- `SelectedArtifact` — the single selected artifact, or `$null` when none is eligible.
- `Observations` — all artifact eligibility observations.
- `IsDeterministic` — `true` for the deterministic Core implementation.

## Phase Boundary

Phase 4D answers: `Which artifact belonging to an eligible release is compatible and preferred?`

It does not determine whether the release itself is eligible, download or verify bytes, choose an installer, or install software. Downloading begins in Phase 5 and installation begins in Phase 6.
