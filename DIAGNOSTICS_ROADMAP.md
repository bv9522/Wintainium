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
- The Windows reconciliation plugin now emits an explicit `WindowsReconciliationEvidenceIncomplete` summary when zero registrations match and any configured registry observation failed. It reports safe counts (candidates, configured locations, failed reads) and match mode. Ambiguous evidence now includes candidate count, match mode, location count, and registry-read-failure count. These changes are committed but have not yet been run locally.
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
- Strengthened the Windows reconciliation tests so ambiguous registrations and registry-read failures assert the structured reason survives alongside `Unknown` evidence, rather than asserting only the state value.
- Strengthened the authoritative persistence-failure test to seed and re-read the prior persisted record, proving a failed write does not replace authoritative state.
- Desktop installed-state and update-decision mappers now convert mapping exceptions into explicit failed result objects (`DesktopInstalledStateMappingFailed` / `DesktopUpdateDecisionMappingFailed`) instead of losing the structured stage result to the outer generic catch.
- The refresh trace labels these as dedicated `DesktopInstalledStateMapping`, `DesktopPersistedStateMapping`, or `DesktopUpdateDecisionMapping` stages. Stage reason codes now fall back to the first structured error/warning code when Core provides no explicit reason; installation state remains unchanged when mapping fails.
- The application-model projection boundary is now covered too: an installed-state `ApplicationId` mismatch or malformed projection is classified as a dedicated desktop mapping failure rather than mislabeled as a Core reconciliation failure. The failure stage records identical before/after installation state.
- Brian confirmed the Release desktop build succeeded after the projection-boundary mapping change. Runtime verification of the copied report and state preservation remains outstanding; D4 is still open.
- Important scope correction: Add Software source-resolution diagnostics are unrelated to the `Unknown` installation-state problem. The installed-state report is retained only during dashboard refresh and displayed in Application Details when that window is opened; it does not auto-open. Brian reports that the running app is not surfacing this report, so treat the diagnostics UI path as unverified—not as evidence that the `Unknown` root cause is known.
- Root cause found for the missing live Details presentation: `ApplicationDetailsWindow` reads the diagnostics store once in its constructor, while `MainWindow.RefreshSingleApplicationAsync` may store the result later without notifying an already-open Details window. This leaves the report hidden and Copy Diagnostics disabled until another operation happens to refresh the window. Commits `14a9f51` and `21ddd3f` now push a completed dashboard refresh into the matching open Details window, update its application facts, refresh the report presentation, and show whether dashboard refresh has completed. This fixes report visibility only; it does not yet explain why the eight applications themselves resolve to `Unknown`. Runtime verification remains outstanding.
- Test `Installed`, confirmed `NotInstalled`, ambiguous evidence, registry-read failure, invalid/missing policy, missing persisted state, persistence failure, update-decision failure, and desktop mapping failure.
- Assert the first stage where state becomes `Unknown` and verify that the reason survives to the report.
- Build the desktop and run focused plus full Pester suites locally.
- Reuse and strengthen existing focused coverage rather than duplicate the same assertions: authoritative transition/persistence tests cover Installed, NotInstalled, Unknown preservation, missing prior state, and persistence failure; Windows reconciliation tests cover ambiguous candidates, registry-read failure, and missing/invalid settings; public reconciliation tests cover policy-validation short-circuiting and reason/event propagation.
- D4-specific remaining validation is local desktop verification: confirm update-decision failures and the new dedicated mapping-failure stages appear in the copied report, the earliest uncertain/failed stage is correct, and positive controls remain unchanged. Those paths require a local desktop run because the repository currently has no dedicated .NET desktop unit-test project.
- **Acceptance:** automated Core tests and local desktop scenario checks explain outcomes without altering state authority or existing behavior.

### D5 — Diagnose the eight entries still showing Unknown
Brian reports that 10 applications were onboarded, with Audacity and 7-Zip recognized and the other eight showing `Unknown`. The five named earlier (AMD Drivers and Support, Attribute Changer, Core Temp, CPU-Z, and Equalizer APO) are examples, not the complete set. Compare all eight entries' manifest policy, registry evidence, Core state, update decision, and dashboard projection. Only then implement a behavior fix supported by the evidence.

## Current status

- [x] Confirmed that Add Software source-resolution diagnostics are a separate successful path.
- [x] Located where authoritative reconciliation and desktop refresh results can lose explanatory detail.
- [x] Defined the diagnostic stages and behavior guardrails.
- [x] D1 — Preserve authoritative Core explanations (focused authoritative/public reconciliation tests passed locally; Brian subsequently confirmed the desktop build and all tests passed).
- [x] D2 — Carry full structured results through the desktop (Brian confirmed the Release build and all tests passed).
- [x] D3 — Produce a copyable refresh report (Brian confirmed Release build succeeded and all 708/708 tests passed).
- [ ] D4 — Validate end-to-end failure modes (targeted Core assertions and explicit desktop mapping-failure reporting committed; latest Release build confirmed by Brian; runtime report/state-preservation verification outstanding).
- [ ] D5 — **Current priority:** identify why eight of the ten onboarded apps show `Unknown` (Audacity and 7-Zip are recognized; the five named examples are not the full set). The first code inspection confirms the Windows reconciler returns `Unknown` when multiple registry entries match, or when no entries match and one or more registry locations failed to read. It returns `NotInstalled` when the registry scan succeeds with zero matches. This narrows the likely cause but does not prove which branch affects Brian's eight apps. New safe diagnostic summary fields have been added for candidate count, match mode, configured registry locations, and failed reads. After Brian builds/runs this change, use one affected app's copied Installed-State Refresh Report to determine the actual branch before changing behavior.

## D4 local desktop scenario checks

For the desktop-only boundary checks, use a disposable test manifest/application fixture where practical. Do not change a real application's policy to force a result, and do not persist a guessed state.

1. **Update-decision failure:** cause the update-decision operation to fail in a controlled fixture. Open that application's existing Details diagnostics and copy the report. Confirm the Update Decision stage carries the failure/reason and the report's first-attention stage points there unless an earlier stage already failed or became Unknown.
2. **Desktop mapping failure:** use a controlled malformed Core-shaped result in a test-only fixture. Confirm mapping failure is recorded as a stage failure, the prior/unknown installation state is not converted into Installed/NotInstalled, and Copy Diagnostics retains the mapping reason.
3. **Reason/report contract:** for ambiguous evidence and registry-read failure, confirm the first stage with an Unknown post-state is reported, the reason/event survives into the copied text, and safe-context filtering excludes raw registry subkeys and unrelated application names.
4. **Positive controls:** verify confirmed Installed and confirmed NotInstalled transitions report the expected final state and do not flag a successful stage as the first failed/uncertain stage.
5. **Missing state/policy:** verify the report distinguishes a missing persisted-state record (prior state Unknown) from invalid/missing policy (reconciliation does not run or returns its explicit validation failure).

## Local verification

After each relevant change, run focused Pester tests for reconciliation/state persistence and then the full suite:

```powershell
Invoke-Pester .\tests\Unit\AuthoritativeStateReconciliation.Tests.ps1 -Output Detailed
Invoke-Pester .\tests\Unit\PublicApplicationReconciliation.Tests.ps1 -Output Detailed
Invoke-Pester .\tests\Unit\InstalledApplicationStatePersistence.Tests.ps1 -Output Detailed
Invoke-Pester .\tests\Unit\WindowsInstalledApplicationReconciliation.Tests.ps1 -Output Detailed
Invoke-Pester .\tests -Output Detailed
dotnet build .\src\Wintainium.Desktop\Wintainium.Desktop.csproj -c Release
```
