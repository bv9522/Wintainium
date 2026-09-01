# AI Development Context

Use this file as a compact orientation guide when assisting with Wintainium.

## Required reading order

1. `PROJECT.md`
2. `ROADMAP.md`
3. `ARCHITECTURE.md`
4. `docs/Phase5DownloadEngine.md` for the current download boundary
5. Relevant contracts and tests for the target component

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
- Artifact verification, installer selection, and execution belong to Phase 6.
- End-to-end lifecycle orchestration belongs to Phase 7.
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

Phase 6 is the next implementation phase and will own artifact verification,
installer-plugin selection, controlled installation, and installation recovery.
