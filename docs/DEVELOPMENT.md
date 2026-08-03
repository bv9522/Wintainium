# Development Guidelines

## Phase 1 architecture freeze

Decisions #001 through #005 in the Architecture Decision Log are stable for
Phase 1. A proposed architectural change requires a documented reason,
tradeoffs, and a new decision-log entry before implementation changes.

## Implementation standards

- Prefer clear, maintainable PowerShell over clever solutions.
- Core orchestrates; plugins provide capabilities; manifests declare intent;
  state records reality.
- Keep application-specific logic out of the core.
- Exchange structured objects and structured errors between components.
- Comment non-obvious design decisions and keep components testable.
- Preserve backward compatibility when practical.
- Do not add abstractions before a demonstrated need.

## Phase 1 boundaries

Phase 1 validates application definitions offline. It includes manifest schema
validation, semantic validation, plugin-descriptor resolution, structured
logging, and automated tests. It excludes network access, downloading,
installation, scheduling, GUI functionality, and managed-application state.

## Approved baseline

- PowerShell 7.4 LTS or later compatible runtime
- JSON Schema Draft 2020-12
- Pester test framework
