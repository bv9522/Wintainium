# Phase 12.11 — Unsupported/Interactive Source Handling

## Status

**Complete and validated; lock pending final Phase 12.12 integration, regression, audit, and lock.**

Phase 12.11 establishes the failure-side source-onboarding contract across Core and the WinUI desktop client. Deterministic source-resolution failures remain structured Core outcomes, and the desktop client presents those outcomes without implementing provider or source-resolution logic.

## Scope

The supported failure statuses are:

- `SourceUnsupported`
- `SourceAmbiguous`
- `SourceUnavailable`
- `AuthenticationRequired`
- `InteractiveResolutionRequired`
- `SourceResponseInvalid`

For all of these outcomes:

- Core returns an unsuccessful structured onboarding result.
- No normalized application definition is created.
- No application manifest is persisted.
- Operation correlation and structured diagnostics remain available to the caller.
- The desktop client maps the status to user-facing UX.

Authentication-required and interactive-resolution outcomes may offer an **Open Source** action. That action launches the user-supplied source URI through the operating-system launcher; it does not resolve the source, select an artifact, create application state, or bypass Core.

## Test fixture boundary

The deterministic failure provider is a test fixture under:

`tests/Fixtures/Plugins/SourceResolutionFailure/`

It is copied into isolated Pester plugin roots for Core tests. It is not part of the production `plugins/` directory.

For the manual desktop checkpoint, Debug builds may opt into an external plugin root through:

`WINTAINIUM_DESKTOP_PLUGIN_ROOT`

The override is read only by `WintainiumApplicationOnboardingService` in Debug builds. Release builds ignore the variable, and the default production plugin root remains unchanged when the variable is absent.

This seam exists solely to exercise the desktop presentation boundary against deterministic test-provider outcomes without shipping the fixture as a production provider.

## Validation

### Core focused regression

`tests/Unit/ApplicationOnboarding.Tests.ps1`

Validated checkpoint:

**14/14 green**

Coverage includes:

- structured propagation of all six failure statuses;
- no application state or manifest persistence on source-resolution failure;
- multiple capable providers producing `SourceAmbiguous` rather than silent selection;
- OperationId preservation.

### Desktop manual checkpoint

The Debug desktop build was run with the source-resolution failure fixture selected through `WINTAINIUM_DESKTOP_PLUGIN_ROOT`.

All six scenarios passed:

| Source | Expected result | Observed |
|---|---|---|
| `https://example.invalid/unsupported` | Source not supported | Passed |
| `https://example.invalid/ambiguous` | Source is ambiguous | Passed |
| `https://example.invalid/unavailable` | Source is unavailable | Passed |
| `https://example.invalid/authentication` | Authentication required + Open Source | Passed |
| `https://example.invalid/interactive` | Interactive resolution required + Open Source | Passed |
| `https://example.invalid/response-invalid` | Source response could not be resolved | Passed |

No application was expected to be created by these scenarios.

## Architectural boundary

The resulting flow is:

```
Source URL
   |
   v
Core source resolution
   |
   +--> structured failure status
   |
   v
Desktop onboarding result mapping
   |
   +--> explanatory UX
   +--> optional Open Source action
```

The desktop layer does not inspect URLs to determine provider behavior, interpret provider responses, construct application policy, or perform source resolution.

## Lock boundary

12.11 is considered implementation-complete and manually validated. Final phase locking remains part of **12.12 — Integration, Regression, Audit & Lock**, which will reconcile the Phase 12 documentation and perform the final regression/audit checkpoint.
