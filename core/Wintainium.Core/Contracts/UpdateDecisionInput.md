# Phase 4 Update Decision Input Contract

## Purpose

`UpdateDecisionInput` is the internal Core input boundary for Phase 4 update determination.

It carries already-validated application-management inputs into the Phase 4 decision pipeline without coupling that pipeline to the mechanism that discovered installed application state.

## Inputs

The input contains:

- `Manifest` — the validated internal Wintainium application manifest.
- `InstalledState` — a validated `InstalledApplicationState` object representing the currently observed application state.
- `ProviderResult` — the validated provider discovery result containing upstream release and artifact metadata.

Provider metadata remains untrusted source metadata. This boundary does not perform trust evaluation, version comparison, release eligibility, artifact selection, downloading, or installation.

## Invariants

- `Manifest` is supplied by the existing manifest engine; this boundary does not import manifests or access the network.
- `InstalledState` is supplied as a provider-independent Core model; this boundary does not enumerate Windows installation sources.
- `InstalledState.ApplicationId` must correspond to the manifest application identity.
- Provider discovery data remains a separate input and is not copied into installed state.
- Construction is deterministic and side-effect-free.
- Inputs are treated as observations/data; the boundary does not mutate them.

## Phase Boundary

Phase 4 uses this input to determine what should be updated. Version normalization/comparison, release eligibility, artifact eligibility/selection, and the final update decision are separate Phase 4 stages. Downloading begins in Phase 5 and installation in Phase 6.
