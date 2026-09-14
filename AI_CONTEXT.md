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
- Cancellation is control flow, not an operation-state status; operation state remains Pending/Running/Failed/Completed.
- The mandatory verification stage remains explicit and must not be bypassed by orchestration.
- The Android/Termux environment is a secondary test environment; Wintainium remains Windows-first.

## Current state

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

Phase 7 is implemented and locked through 7I. The lifecycle now establishes a
parent operation context, deterministic seven-stage plan, immutable operation
state and transitions, explicit cancellation control flow, Core-owned single-
stage execution, single-stage coordination, multi-stage workflow coordination,
and a lifecycle entry boundary that initializes state once and delegates the
complete operation to the workflow coordinator. The workflow preserves the
mandatory verification boundary and does not infer trust from download success.

Phase 8A is complete. The public PowerShell surface is intentionally limited to
`Get-WintainiumManifest`, `Test-WintainiumApplicationDefinition`, and
`Get-WintainiumApplicationRelease`. Low-level installer-request construction is
internal. The exported module boundary is presentation-neutral and returns
structured objects rather than formatted output.

Phase 8B is in progress. Public result contracts, stable error categories,
comment-based help, contract tests, and the Core-owned orchestration composition
requirements are documented. The public end-to-end update command remains
withheld because update decisions require authoritative installed state and the
current repository does not yet have the required state retrieval/persistence
boundary. Callers must not manufacture that state or construct internal
orchestration objects to bypass the boundary.

Phase 8C has begun. `docs/GettingStarted.md`, `docs/CLI.md`, and
`docs/ManifestAuthoring.md` provide the initial user-facing documentation
layer. Documentation must describe implemented behavior and must not imply that
internal orchestration or speculative persistence features are public.

The current full-suite regression checkpoint is 331/331 green after the latest
public-contract and documentation changes.

The repository is authoritative over this context. When this file conflicts
with implementation, contracts, or tests, inspect the repository and update
this orientation document rather than relying on stale assumptions.
