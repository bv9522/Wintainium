# AI Development Context

Use this file as a compact orientation guide when assisting with Wintainium.

## Required reading order

1. `PROJECT.md`
2. `ROADMAP.md`
3. `ARCHITECTURE.md`
4. Relevant phase contracts and tests for the target component
5. Relevant implementation files for the target boundary

## Working rules

- Preserve the engine/GUI boundary.
- Add application support through manifests and provider or installer plugins whenever possible.
- Avoid unnecessary dependencies and hidden side effects.
- Keep public PowerShell functions clearly commented and testable.
- Do not overwrite user files without explicit confirmation or policy.
- Update relevant documentation and tests with behavior changes.
- Providers discover upstream releases and artifacts; Core owns update decisions.
- Phase 4 is locked and owns deterministic update-target selection.
- Phase 5 is locked and owns controlled artifact acquisition only.
- A successful download does not establish artifact trust or installation readiness.
- Phase 6 is locked and owns installer selection, controlled installer invocation, process lifecycle semantics, and structured installation results.
- Phase 7 is implemented through 7I and locked; orchestration coordinates lifecycle flow without moving stage business rules into orchestration or the GUI.
- Cancellation remains Core-owned control flow. The desktop presentation layer may expose a Cancel action and represent a cancelled presentation outcome, but it does not determine lifecycle cancellation semantics.
- The mandatory verification stage remains explicit and must not be bypassed by orchestration.
- The Android/Termux environment is a secondary test environment; Wintainium remains Windows-first.

## Current state

Phase 10 is complete and locked. The public PowerShell surface now contains exactly four commands: Get-WintainiumManifest, Test-WintainiumApplicationDefinition, Get-WintainiumApplicationRelease, and Invoke-WintainiumApplicationUpdate. The public update command invokes the complete Core-owned lifecycle and projects its internal result into the stable PublicApplicationUpdateResult contract. Phase 11A has now validated the planned C#/.NET integration mechanism with an isolated .NET 10 probe using Microsoft.PowerShell.SDK 7.6.6; embedded runspace hosting can import Wintainium.Core, resolve a public command, execute it, and receive structured results without changing the machine execution policy. The probe is an audit artifact for Phase 11A and is not the production GUI.


Phases 1–4 are implemented, tested, and locked. Phase 3 includes the versioned
provider contract and GitHub Releases reference provider. Phase 4 produces a
structured update decision from validated manifest policy, installed state, and
provider observations.

Phase 5 is implemented and locked. Its Core-owned download boundary validates
the selected artifact target, enforces HTTPS and destination safety, streams
bytes to a temporary file, publishes only completed transfers, cleans partial
data, supports cancellation, and returns structured success/failure results
with operation correlation. Phase 5 does not verify trust or execute artifacts.

Phase 6 is implemented and locked. It defines installer input validation,
installer descriptors and capability validation, Core-owned installer
selection, controlled installer invocation preparation, controlled process
lifecycle semantics, the fixed installer-plugin operation boundary, and
structured installation results. A targeted 6E completion-race correction uses
`WaitForExitAsync()` as the authoritative normal-completion signal without
changing the locked process contract. Phase 6 does not reconcile post-install
application state.

Phase 7 is implemented and locked through 7I. The lifecycle establishes a
parent operation context, deterministic seven-stage plan, immutable operation
state and transitions, explicit cancellation control flow, Core-owned single-
stage execution, single-stage coordination, multi-stage workflow coordination,
and a lifecycle entry boundary that initializes state once and delegates the
complete operation to the workflow coordinator. The workflow preserves the
mandatory verification boundary and does not infer trust from download success.

Phase 8A is complete. The public PowerShell surface was intentionally limited to the supported presentation-neutral commands at that time. Low-level installer-request construction remains internal.

Phase 8B is complete for the Phase 8-era public surface. Public result contracts, stable error categories, comment-based help, contract tests, and Core-owned orchestration composition requirements are documented.

Phase 10 subsequently completed the authoritative installed-state composition and exposed the complete end-to-end update operation as the fourth public command. The public update result contract keeps internal lifecycle state and private request objects out of the presentation boundary.

Phase 8C is complete for the current implementation boundary. The user-facing
documentation layer covers Getting Started, CLI usage, manifest authoring,
and diagnostics/troubleshooting. Documentation describes implemented behavior
without inventing persistent configuration or update/install interfaces.

Phase 8D is complete and locked. Release packaging is deterministic at the
file-selection and relative-layout level, with the Core module manifest as the
authoritative version source. The distributable boundary preserves required
runtime and documentation assets while excluding development material and
repository placeholders. The independent validator enforces the documented
boundary and public export surface. The builder preflights source assets,
protects the output boundary, refuses overwrites, validates before archiving,
and cleans partial output after post-creation failure. The final Phase 8D
regression checkpoint is 356/356 green.

Phase 8E is complete and locked. It established the upgrade and persistence contract: classifying
program files, user configuration, application state, logs, caches, manifests,
and temporary artifacts; defining safe replacement and preservation behavior;
establishing the authoritative installed-application state boundary needed by
update orchestration; and validating a supported N→N+1 upgrade path without
introducing speculative persistence infrastructure.

`docs/UpgradePersistence.md` defines the current 8E ownership and transaction
contract. Core now contains internal JSON persistence operations for the
normalized `InstalledApplicationState` representation. Missing records return
an explicit `Unknown` state; invalid persisted data is rejected; writes replace
an existing application record atomically through a temporary file; and the
store preserves separate records by stable `ApplicationId`. This persistence
layer is storage only and does not make update decisions or execute applications.

The repository is authoritative over this context. When this file conflicts with implementation, contracts, or tests, inspect the repository and update this orientation document rather than relying on stale assumptions.

Phase 11A is complete. It established the Windows/.NET toolchain baseline, validated the official WinUI 3 template can restore and build, validated in-process PowerShell SDK hosting from .NET 10, and reconciled the GUI-readiness documentation with the completed Phase 10 public update boundary. Phase 11B established the production C#/.NET GUI project foundation; 11C established and locked the Windows application shell; 11D established and locked the in-process engine integration boundary; 11E established and locked the application collection/model/query boundary; 11F established and locked application details and release information; 11G established and locked structured operation state and diagnostics; 11H established and locked progress/cancellation presentation; 11I established and locked the desktop settings/configuration foundation; and 11J established and locked focused GUI testing and integration hardening. The desktop EngineProbe validates the adapter, structured mapping, settings, and cancellation boundaries. The 11J WinUI build and interaction checkpoint are green. The GUI remains a presentation client of Core.
