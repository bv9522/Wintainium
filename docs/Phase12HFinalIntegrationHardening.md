# Phase 12H — Final Integration Hardening & Phase 12 Lock

## Objective

Complete the final Phase 12 integration audit without adding a second application-management authority to the desktop client.

The final vertical slice is:

`Application Details → public Core command boundary → Core-owned lifecycle → structured update result → authoritative installed-state refresh → desktop presentation → fresh collection observation`

## Final hardening boundary

- Application Details invokes only the desktop release, update, and installed-state services.
- Those services invoke documented public Core commands through the in-process PowerShell host.
- Core remains responsible for provider discovery, update decisions, download, verification, installer selection/execution, reconciliation, persistence, lifecycle policy, and authoritative installed-state semantics.
- Application Details presents the structured update result and authoritative installed-state observation separately.
- After a successful authoritative state read, the details window requests a fresh application collection load from `MainWindow`. The details window does not mutate the collection itself or pass internal Core state into the collection.
- Collection refresh failures are presented separately from the already-successful authoritative installed-state refresh.
- Cancellation is owned by the active operation handler: closing the details window requests cancellation, while the operation handler owns final disposal of its cancellation source.
- A cancelled operation or an exception before a structured update result is available does not manufacture installed state or trigger a false authoritative refresh.
- Structured errors, warnings, stage diagnostics, and OperationId values remain sourced from Core results.

## State authority

The desktop application model is a presentation snapshot.

Installed version and installation state are never inferred from:

- release discovery,
- update completion text,
- lifecycle stage count,
- installer execution assumptions,
- or terminal/console output.

After an update returns a structured result, the only installed-state observation used to update the details model is the public `Get-WintainiumApplicationInstalledState` result.

The main collection is subsequently reloaded through the existing `WintainiumApplicationCollectionService`, which rereads authoritative state for every application.

## Cancellation boundary

There is one active operation per Application Details window.

- Check for Updates and Run Update are disabled while the active operation runs.
- Cancel requests cancellation through the active token source.
- The PowerShell host receives the cancellation token.
- A structured Core cancellation result is presented when available.
- If cancellation interrupts the operation before a structured result can be returned, the UI reports cancellation and does not perform an authoritative refresh.
- Closing the window requests cancellation without disposing the token source concurrently; the active operation's `finally` block owns disposal.

## Collection consistency

A details window receives an application snapshot from the main collection. A completed update can change Core-authoritative installed state, so retaining the original main-window snapshot would leave the collection stale.

The final integration path therefore supplies a narrow presentation callback from `MainWindow` to `ApplicationDetailsWindow`. The callback requests a normal collection reload through `WintainiumApplicationCollectionService`. No installed-state object is copied from the details window into the collection.

If that collection reload fails, the already-refreshed details state remains valid and the UI reports the collection refresh problem as a separate diagnostic.

## Verification boundary

Phase 12H requires the following checkpoints before final lock:

1. Desktop x64 Debug build.
2. Desktop EngineProbe.
3. Full PowerShell/Pester regression covering the established Phase 1–10 baseline and Phase 12 Core additions.
4. Manual real-application desktop update exercise, where practical, to observe the complete presentation path against a real configured application.

A manual real-application update is an integration observation, not a substitute for the deterministic Core regression suite.

## Non-goals

Phase 12H does not:

- move lifecycle logic into C#,
- introduce a new update engine,
- infer installation state from UI events,
- parse console output,
- expose private Core lifecycle/provider/installer objects,
- redesign the Core public contract,
- add a persistent desktop-side state authority,
- or broaden the Phase 12 feature surface beyond final integration hardening.

## Lock boundary

Phase 12 is locked only after the final local checkpoints above are observed as green/passed.

Until those checkpoints are observed, this document records the intended final integration boundary rather than claiming final Phase 12 completion.
