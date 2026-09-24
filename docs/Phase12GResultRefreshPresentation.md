# Phase 12G — Result + Refresh Presentation

## Objective

Complete the Application Details presentation of update outcomes and authoritative installed-state refresh without introducing a second state authority in the desktop client.

## Boundary

Application Details
        |
        +--> WintainiumApplicationUpdateService
        |          |
        |          v
        |   Structured public update result
        |          |
        |          v
        |   Update result presentation
        |
        +--> WintainiumApplicationInstalledStateService
                   |
                   v
            Authoritative installed-state observation
                   |
                   v
            Installed-state presentation

The update result and installed-state observation remain separate contracts. The desktop client presents both observations and does not derive one from the other.

## Implementation

- Application Details now presents update outcome status separately from the existing release-discovery status.
- Public lifecycle stage summaries are presented individually with sequence, name, outcome, status, and structured stage error information when available.
- Authoritative installed-state refresh has its own status surface and no longer overwrites release-discovery status.
- A completed structured update result triggers the authoritative installed-state refresh; the application model is updated only from the state Core reports.
- A cancelled update explicitly reports that authoritative refresh was not performed because no structured update result was available.
- A failed update without a structured result does not manufacture installed state.
- Existing structured Errors and Warnings remain preserved in the operation presentation.

## Architectural constraints

The desktop client still must not:

- set InstalledVersion from a requested or discovered release;
- infer installation from update success;
- treat an update result as an installed-state observation;
- invoke lifecycle stages, providers, installers, downloaders, verification, or reconciliation directly;
- parse terminal output.

## Checkpoint

Phase 12G is green. Brian observed the local x64 Debug desktop build succeed after the final presentation hardening. The checkpoint validates the WinUI XAML/code-behind integration for the distinct update-result, lifecycle-stage, release-discovery, and authoritative-refresh presentation surfaces.

The Phase 12F EngineProbe remains the automated contract checkpoint for structured update-result and authoritative-refresh mapping. A broader real-application update execution remains a Phase 12H integration-hardening concern.

**Status: Complete and locked.**

## Next boundary

Phase 12H will perform final integration hardening, full regression, documentation reconciliation, and the Phase 12 lock.
