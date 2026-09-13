# Orchestration Composition Boundary

## Purpose

Phase 7 deliberately separated lifecycle coordination from stage implementation.
`Invoke-WintainiumOrchestrationLifecycle` owns lifecycle initialization and delegates
stage traversal to the workflow; the workflow receives a `StageFactory` that supplies
the input and executor for each stage. This keeps orchestration policy independent of
providers, download mechanics, installers, and presentation.

Phase 8 must add the missing **Core-owned composition boundary** before exposing a
public end-to-end update command.

## Required boundary

The eventual production composition layer must be owned by `Wintainium.Core` and
must translate a stable public request plus Core-managed dependencies into the seven
stage bindings:

1. `ManifestValidation`
2. `ReleaseDiscovery`
3. `UpdateDecision`
4. `Download`
5. `Verification`
6. `InstallerSelection`
7. `Installation`

The public command must call this composition layer and then the locked Phase 7
lifecycle. A caller must not construct or supply:

- `StagePlan`
- `CancellationContext`
- `StageFactory`
- provider requests
- download requests
- installer requests
- stage-specific execution delegates

Those are Core implementation details.

## Current dependency boundary

A complete production composition cannot be implemented honestly yet because the
current orchestration request contains `ManifestPath`, `MachineArchitecture`, and
`DownloadRoot`, while the locked update-decision contract also requires an
`InstalledState` and a provider result. The Core currently has a constructor for
installed-state objects, but no persistent installed-state discovery/retrieval
operation.

Inventing an installed state, treating every application as installed, or requiring
the public caller to provide an internal state object would all weaken the engine
contract. Therefore the public end-to-end update command remains intentionally
unexposed until the installed-state/persistence boundary is defined.

## Design rule

The composition seam may depend on persistence and other infrastructure through
explicit Core-owned contracts. The lifecycle itself must not acquire persistence,
inspect the registry, discover installers, or perform presentation work. This keeps
the architecture aligned with:

> Manifest describes. Provider discovers. Core decides. Download obtains.
> Verification establishes trust. Installer applies. Orchestration coordinates.
> UX presents.

## Phase 8 sequencing consequence

The public result contract is established now, but the public update command should
follow the persistence/installed-state contract work in Phase 8E rather than being
forced into 8B prematurely. Once that dependency exists, 8B.2 can expose a thin
public command over the already-defined Core composition seam without changing the
Phase 7 lifecycle contract.
