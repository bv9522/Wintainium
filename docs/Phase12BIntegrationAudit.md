# Phase 12B — Integration, Regression, Audit & Lock

## Status

**Integration audit prepared; final lock pending the focused regression and desktop build/manual checkpoint.**

12.12 is the final Phase 12B subphase. Its purpose is to verify that source onboarding remains one coherent vertical slice across the provider, Core, persistence, and desktop presentation boundaries, reconcile documentation, and establish the lock boundary without expanding Phase 12B into update execution.

## Audit boundary

The Phase 12B source-onboarding flow is:

```
Desktop source URL
      |
      v
Core application onboarding
      |
      +-- URI validation
      +-- source-resolution provider selection
      +-- structured source-resolution result
      +-- normalized application definition
      +-- Core-owned default/explicit policy
      +-- schema validation
      +-- authoritative manifest persistence
      |
      v
Desktop collection presentation
```

The desktop client does not:

- select a provider;
- parse provider-specific source formats;
- construct lifecycle policy;
- select release/artifact candidates;
- persist manifests itself;
- infer success from formatted PowerShell output.

The Core does not treat an unsupported, ambiguous, unavailable, authentication-required, interactive, or invalid source-resolution result as a partial application.

## Established source-resolution coverage

The two source-resolution vertical slices are:

1. GitHub repository/release URL normalization.
2. Structured official-download-page identity resolution.

The live 12.10B checkpoint validated:

- GitHub repository URL;
- GitHub releases URL;
- 7-Zip official download page;
- VLC official download page.

The final observed live checkpoint was **4/4 green** on 2026-09-22.

12.11 added deterministic failure coverage for:

- `SourceUnsupported`;
- `SourceAmbiguous`;
- `SourceUnavailable`;
- `AuthenticationRequired`;
- `InteractiveResolutionRequired`;
- `SourceResponseInvalid`.

The focused Core checkpoint was **14/14 green** and the Debug desktop manual checkpoint was **6/6 passed**.

## Persistence boundary

Successful onboarding persists only after Core has:

1. resolved the source;
2. constructed the normalized application definition;
3. applied/validated the Core-owned policy;
4. validated the application definition against the authoritative schema.

Source-resolution failures and policy-normalization failures do not create application manifests.

The authoritative destination remains the existing application manifest collection. Desktop settings and session-only notes are not part of this Phase 12B persistence boundary.

## Test-fixture boundary

The source-resolution failure provider remains under:

`tests/Fixtures/Plugins/SourceResolutionFailure/`

It is copied into isolated test plugin roots for Pester coverage.

The Debug-only desktop environment-variable seam:

`WINTAINIUM_DESKTOP_PLUGIN_ROOT`

exists only to point a Debug desktop process at that fixture during manual validation. The variable is ignored by Release builds and is not a production plugin-registration mechanism.

## Regression checkpoint

Run the focused Core source-onboarding regression:

```powershell
Invoke-Pester .\tests\Unit\ApplicationOnboarding.Tests.ps1
```

Expected checkpoint:

**14/14 green**

Then validate the real-world source-resolution integration:

```powershell
Invoke-Pester .\tests\Integration\Phase12B-RealWorldSourceValidation.Tests.ps1
```

Expected checkpoint:

**4/4 green**

The desktop checkpoint remains:

1. Build the x64 Debug desktop application.
2. Set `WINTAINIUM_DESKTOP_PLUGIN_ROOT` to the source-resolution failure fixture.
3. Launch `Wintainium.exe` from the same PowerShell session.
4. Exercise all six 12.11 source-resolution failure URLs.
5. Confirm the six expected UX outcomes and confirm no application is added.

A successful 12.12 lock must be based on observed local results for these checkpoints rather than an assumed build/test state.

## Lock boundary

When the focused Core regression, live source-resolution integration regression, desktop build, and manual failure-handling checkpoint are confirmed, Phase 12B may be marked **complete and locked**.

That lock covers:

- source URL onboarding;
- deterministic source resolution;
- normalized application-definition construction;
- Core-owned onboarding policy;
- schema-validated application-definition persistence;
- structured source-resolution failures;
- desktop presentation of those failures;
- the validated GitHub and structured official-download-page source families.

It does **not** claim live validation of:

- release discovery;
- update decisions;
- artifact selection;
- downloading;
- verification;
- installation;
- reconciliation;
- end-to-end update execution.

Those remain governed by the existing Phase 1–10 lifecycle contracts and later desktop integration work.
