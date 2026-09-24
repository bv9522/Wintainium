# Phase 12D — Release Discovery Completion

## Status

**Complete.**

Phase 12D establishes the desktop release-discovery vertical slice over the
documented Core boundary.

## Boundary

```
Application Details
        |
        v
WintainiumApplicationReleaseService
        |
        v
WintainiumCoreClient
        |
        v
Get-WintainiumApplicationRelease
        |
        v
Core-owned release discovery
        |
        v
Structured public release result
        |
        v
Desktop release mapper/model
```

Core remains authoritative for provider discovery, release normalization,
artifact data, release eligibility, and structured failure semantics. The
desktop layer presents the public result and does not select providers,
construct provider requests, or implement release policy.

## Checkpoint

The focused public release boundary test is:

`Invoke-Pester .\tests\Unit\PublicApplicationRelease.Tests.ps1`

Brian's observed checkpoint: **6/6 green**.

Coverage includes:

- public command exposure;
- successful structured release discovery and OperationId correlation;
- successful no-release observation without inventing a release;
- structured provider failure;
- invalid OperationId rejection;
- malformed provider release rejection before the public result.

The existing desktop release model, mapper, service, Core adapter, and
application-details release action complete the presentation vertical slice.

## Non-goals

Phase 12D does not claim that update execution, download, verification,
installation, reconciliation, or post-update authoritative refresh are
complete. Those remain downstream Phase 12 work.
