# Installed-State Diagnostics Roadmap

## Goal

Identify the earliest stage at which a managed application's installed or update state becomes `Unknown`, preserve the explanation across Core and desktop boundaries, and expose a copyable report without changing reconciliation behavior merely to make the dashboard look healthier.

This work is separate from Add Software source-resolution diagnostics. Source-resolution diagnostics remain in Add Software. Installed-state refresh diagnostics belong to the selected application's existing diagnostics experience; no automatic App Details window opening is planned.

## Guardrails

- Do not change completed themes or visual appearances.
- Do not convert an unresolved `Unknown` into `Installed` or `NotInstalled`.
- Preserve Core as the authority for installed state and policy.
- Capture relevant registry evidence only; do not dump unrelated installed-software entries.
- Keep source-resolution and refresh/reconciliation reports explicitly labeled as different operation types.
- Prefer structured diagnostic codes, stages, and before/after state values over unstructured log dumps.

## Diagnostic stages

1. **Manifest and identity** — application ID, manifest path, validation result, and resolved reconciliation plugin.
2. **Refresh orchestration** — operation ID, stage outcome, and any exception or cancellation.
3. **Prior persisted state** — whether state was present, its state value, and whether retrieval succeeded.
4. **Reconciliation evidence collection** — evidence source, normalized observed state, matching mode, candidate count, and registry read failures where available.
5. **Evidence interpretation** — authoritative reason code, prior state, observed state, and whether evidence was accepted or preserved.
6. **Persistence** — whether state was written, deliberately preserved, or failed to persist.
7. **Desktop result mapping** — Core state and status, mapped state, and mapping errors.
8. **Update decision** — installed state used, decision status/reason code, release selection outcome, errors and warnings.
9. **Dashboard projection** — final installation state and update status assigned to the application model.

Every stage should record a start/result marker or an explicit skipped reason, so an incomplete trace is distinguishable from a stage that ran and returned no findings.

## Delivery plan

### D1 — Preserve authoritative Core explanations
- Extend authoritative reconciliation results with structured warnings and reason codes on every outcome.
- When evidence is `Unknown`, preserve prior trustworthy state and return an explicit diagnostic explaining that persistence was intentionally skipped.
- Propagate the authoritative reason/warnings through the public reconciliation result.
- Add focused Pester tests for unknown evidence, accepted evidence, and failures.
- **Acceptance:** a caller can distinguish `UnknownEvidencePreserved` from a failed reconciliation or failed persistence without inferring from the final state alone.

### D2 — Carry full structured results through the desktop
- Extend desktop result models to retain Core `LogEvents`, reason codes, and reconciliation sub-results needed for investigation.
- Preserve per-stage results in the application refresh result rather than flattening errors/warnings into anonymous lists.
- Record pre/post state values and stage status in a refresh trace.
- Add mapping/contract tests.
- **Acceptance:** no relevant Core diagnostic is discarded between PowerShell output and the refresh result.

D2 implementation notes:
- Added a structured desktop log-event model retaining severity, operation ID, component, event name, message, and each context key/value.
- Installed-state refresh results now retain Core log events and a mapped reconciliation sub-result (status, observed evidence, reason code, errors, warnings, and nested events).
- Update-decision results retain Core log events.
- Application refresh results now retain ordered per-stage results for reconciliation, persisted-state read, and update decision, including operation IDs, stage status/reason codes, before/after installation states, and stage-scoped errors/warnings/events.
- The current per-application refresh result is retained in a thread-safe desktop diagnostics store so the next step can surface it in the existing selected-application diagnostics experience.
- Core diagnostic extra fields are preserved through a safe allowlist (including registry scope/view and stage/state context); raw subkeys and unrelated software names are excluded.
- Existing aggregate errors/warnings remain available for compatibility; public Core result property sets were not changed.
- Source-resolution diagnostics and theme/visual appearance files were not changed by D2.

### D3 — Produce a copyable refresh report
- Add a deterministic plain-text diagnostic formatter for one application refresh.
- Include operation/application identity, stage outcomes, state transitions, reason codes, errors, warnings, and concise event context.
- Avoid exposing unrelated registry entries or secrets.
- Expose the report through the existing selected-application diagnostics/copy flow; do not auto-open windows or move source-resolution diagnostics out of Add Software.
- **Acceptance:** a user can copy a single report that identifies the first failed or uncertain stage.

D3 implementation notes:
- Added a deterministic plain-text formatter for a single application's retained refresh trace, with capture timestamp, application/manifest identity, operation IDs, final state, ordered stages, before/after states, reason codes, errors, warnings, and relevant structured log events.
- The report identifies the first failed or uncertain stage, including an Unknown post-stage state and explicit Unknown/evidence-unavailable reason codes.
- Report event context is filtered through a safe allowlist; unrelated application entries and raw registry subkeys are not included.
- Added an Installed-State Refresh section to the existing Application Details diagnostics experience. The existing Copy Diagnostics action includes the selected application's full refresh report, scoped by its application ID.
- Source-resolution diagnostics remain in Add Software; no windows are opened automatically and no theme files were changed.

### D4 — Validate the end-to-end failure modes
- Test `Installed`, confirmed `NotInstalled`, ambiguous evidence, registry-read failure, invalid/missing policy, missing persisted state, persistence failure, update-decision failure, and desktop mapping failure.
- Assert the first stage where state becomes `Unknown` and verify that the reason survives to the report.
- Build the desktop and run focused plus full Pester suites locally.
- **Acceptance:** diagnostic coverage explains outcomes without altering state authority or existing behavior.

### D5 — Diagnose the five real entries
Use the report against AMD Drivers and Support, Attribute Changer, Core Temp, CPU-Z, and Equalizer APO. Compare each entry's manifest policy, registry evidence, Core state, update decision, and dashboard projection. Only then implement a behavior fix supported by the evidence.

## Current status

- [x] Confirmed that Add Software source-resolution diagnostics are a separate successful path.
- [x] Located where authoritative reconciliation and desktop refresh results can lose explanatory detail.
- [x] Defined the diagnostic stages and behavior guardrails.
- [x] D1 — Preserve authoritative Core explanations (focused authoritative/public reconciliation tests passed locally; Brian subsequently confirmed the desktop build and all tests passed).
- [x] D2 — Carry full structured results through the desktop (Brian confirmed the Release build and all tests passed).
- [x] D3 — Produce a copyable refresh report (implementation committed; local build/test verification pending).
- [ ] D4 — Validate end-to-end failure modes.
- [ ] D5 — Diagnose the five real entries.

## Local verification

After each relevant change, run focused Pester tests for reconciliation/state persistence and then the full suite:

```powershell
Invoke-Pester .\tests\Unit\PublicApplicationReconciliation.Tests.ps1 -Output Detailed
Invoke-Pester .\tests\Unit\InstalledApplicationStatePersistence.Tests.ps1 -Output Detailed
Invoke-Pester .\tests\Unit\WindowsInstalledApplicationReconciliation.Tests.ps1 -Output Detailed
Invoke-Pester .\tests -Output Detailed
dotnet build .\src\Wintainium.Desktop\Wintainium.Desktop.csproj -c Release
```
