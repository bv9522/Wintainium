# Development Guidelines

## Architecture decision discipline

Accepted architecture decisions are recorded in `docs/ARCHITECTURE_DECISIONS.md`.
A proposed architectural change requires a documented reason, tradeoffs, and a
new decision-log entry before implementation changes.

## Implementation standards

- Prefer clear, maintainable PowerShell over clever solutions.
- Core orchestrates; plugins provide capabilities; manifests declare intent;
  state records reality.
- Keep application-specific and upstream-specific logic out of Core.
- Exchange structured objects and structured errors between components.
- Comment non-obvious design decisions and keep components testable.
- Preserve backward compatibility when practical.
- Do not add abstractions before a demonstrated need.

## Provider development

Provider Contract v1 is the stable Phase 3 provider boundary. Provider plugins
must communicate with Core through the fixed provider operation and must return
the normalized provider result expected by Core.

Every provider should have both:

1. provider-specific tests for its upstream integration; and
2. reusable provider contract tests for the Core/provider boundary.

The reusable contract harness is documented in
`docs/ProviderContractTestHarness.md`. The harness must remain source-neutral:
GitHub-specific behavior belongs in the GitHub provider's own tests, not in the
shared contract suite.

Providers may communicate with their declared upstream sources. Local manifest
discovery and import remain offline and must not invoke providers.

## Provider source neutrality

GitHub Releases is the first reference provider, not the universal source model.
Future providers may target official vendor websites, vendor APIs, feeds, CDNs,
update manifests, and other authoritative distribution mechanisms. Adding such
a provider should not require a new Core boundary merely because its upstream
transport differs.

## Test expectations

Run the smallest relevant test file while developing, then run the complete
suite before declaring a change complete:

```powershell
Invoke-Pester -Path .\tests\Unit\<RelevantTests>.Tests.ps1
Invoke-Pester -Path .\tests
```

A Phase 3 change is not considered verified when only provider-specific tests
pass. The complete suite is the authoritative regression check.

## Phase boundaries

Phase 1 validates application definitions offline.

Phase 2 establishes local manifest discovery and import.

Phase 3 establishes provider resolution, the fixed provider operation boundary,
the reusable offline provider contract harness, and the first real reference
provider.

Phase 4 is the locked update-decision boundary. It consumes installed state,
manifest policy, and completed provider results to return a deterministic,
explainable structured decision and an optional selected release/artifact.
Providers discover; Core decides. Phase 4 never downloads, verifies bytes,
chooses installers, or installs software. Those responsibilities begin in
Phases 5 and 6; lifecycle orchestration begins in Phase 7.

## Approved baseline

- PowerShell 7.4 LTS or later compatible runtime
- JSON Schema Draft 2020-12
- Pester test framework
