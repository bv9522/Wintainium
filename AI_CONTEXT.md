# AI Development Context

Use this file as a compact orientation guide when assisting with Wintanium.

## Required reading order

1. `PROJECT.md`
2. `ROADMAP.md`
3. `ARCHITECTURE.md`
4. Relevant files in `docs/` and the target component

## Working rules

- Preserve the engine/GUI boundary.
- Add application support through manifests and provider or installer plugins
  whenever possible.
- Avoid unnecessary dependencies and hidden side effects.
- Keep public PowerShell functions clearly commented and testable.
- Do not overwrite user files without explicit confirmation or policy.
- Update relevant documentation and tests with behavior changes.

## Current state

Only the repository foundation exists. No production behavior, update checks,
network operations, or installer support has been implemented.
