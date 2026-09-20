# Wintainium Desktop

This project is the Phase 11 C#/.NET WinUI 3 presentation client over the
existing Wintainium.Core PowerShell engine.

## Boundary

The desktop client must consume documented public Core contracts and structured
results rather than reimplementing engine policy.

The intended dependency direction is:

Wintainium Desktop -> C# engine adapter -> Wintainium.Core public PowerShell API

The desktop project must not call private Core functions, providers, installers,
stage executors, or other internal orchestration components.

## Phase 11C application shell

The 11C shell establishes the agreed desktop interaction model without yet
connecting UI actions to the Core engine:

- One primary Wintainium window with standard Windows window behavior.
- The software collection is the landing view.
- Main-window Sort & Filter action.
- Main-window Add Software action in the lower-right corner.
- Source URL is the primary Add Software input.
- Separate Settings window with General, Appearance, Updates, Sources, and
  Advanced categories.
- Application details remain reserved for the downstream 11F batch, with Do Not Update policy and editable user Notes reserved as application-level presentation/data requirements.
- Windows 11, Y2K, and Frutiger Aero are planned visual styles under Appearance.
- System, Light, and Dark are planned theme choices.
- Wintainium's own release history belongs in the Settings Updates category.
- No engine integration, update logic, provider discovery, or application state
  inference is introduced by this shell.
- Sort & Filter retains the five agreed sort choices (Name A–Z, Name Z–A, Update status,
  Installed status, and Source) and five agreed filters (All software, Update available,
  Up to date, Installed, and Not installed).
- Settings is a functional secondary shell with the five agreed categories; category
  content remains intentionally placeholder-only until its supporting contracts exist.
- The GUI must preserve Core's distinct Unknown installed-state semantics and must not
  infer Unknown as Not Installed.

The shell intentionally uses placeholder collection/settings content. Later
Phase 11 batches will replace those placeholders with real presentation models
and Core-backed behavior.

## Phase 11D engine integration boundary

11D establishes the C#-to-PowerShell boundary without wiring business operations
into the WinUI controls.

- WintainiumPowerShellHost owns in-process Microsoft.PowerShell.SDK hosting,
  runspace creation, scoped hosted execution policy, Core module import, serialized
  invocation, and cancellation-triggered pipeline stopping.
- WintainiumPowerShellHost permits only the four documented public Core command names;
  the generic hosting primitive cannot be used by the desktop layer to invoke arbitrary
  private Core functions.
- The adapter passes documented command parameters through to Core and does not
  construct private lifecycle, stage, provider, installer, download, or
  reconciliation objects.
- WintainiumCoreClient exposes only the four documented public Core commands:
  Get-WintainiumManifest, Test-WintainiumApplicationDefinition,
  Get-WintainiumApplicationRelease, and Invoke-WintainiumApplicationUpdate.
- WintainiumPowerShellInvocationResult is the adapter-local transport boundary;
  PowerShell SDK types remain below the application-facing adapter seam.
- Core import failures are surfaced as adapter construction failures rather than
  being silently converted to successful invocation results.
- Cancellation is represented by an explicit pipeline-stopped outcome; a race
  where a token is cancelled after a normally completed invocation must not
  retroactively turn that successful invocation into a cancelled result.
- The WinUI shell does not yet invoke the adapter. Application models and UI
  behavior will be connected in later Phase 11 batches.
- The PowerShell SDK is hosted in-process; terminal output is never used as an API.\n- `tools/Wintainium.Desktop.EngineProbe` provides a small executable integration probe for the adapter boundary; it verifies in-process hosting, a real public Core invocation, the documented structured result shape, and rejection of arbitrary PowerShell commands.

## Scope discipline

11C establishes the product shell and interaction locations. It does not
finalize every visual detail or implement speculative downstream functionality.

11D establishes the engine integration seam. It does not migrate engine policy
to C#, expose private Core functions, or prematurely build application models,
progress UI, settings persistence, or update workflows into the shell.


## Phase 11E application model foundation

11E introduces the first presentation/application model without moving engine
decisions into C#.

- `WintainiumApplicationModel` represents one tracked application for the desktop
  presentation layer.
- Manifest identity and descriptive metadata are mapped from the documented
  `Get-WintainiumManifest` result.
- Installation state is represented explicitly as `Installed`, `NotInstalled`,
  or `Unknown`; the initial manifest-only model remains `Unknown` until a
  Core-backed installed-state observation is available.
- Update status is explicitly `Unknown` until Core supplies an authoritative
  update decision.
- Installed version and last-updated information remain absent until their
  authoritative sources are connected.
- The mapper does not compare versions, infer installation state, or decide
  whether an update is available.
- The model contains no PowerShell SDK types; PowerShell objects remain confined
  to the adapter-to-mapper boundary.
- The existing EngineProbe now exercises the model mapper and verifies that the
  initial installation and update states remain `Unknown`.

This is the model foundation for the application collection. Collection loading,
installed-state acquisition, update-status population, sorting/filtering, and
interactive list/grid presentation are introduced only as their required
contracts become available in the remaining 11E work.


### Phase 11E application collection boundary

`WintainiumApplicationCollectionService` is the application-layer entry point for loading the tracked software collection. It calls only the documented `Get-WintainiumManifest` Core command and maps its single structured result into `WintainiumApplicationCollectionResult`.

The collection result carries the Core operation identifier, success state, application models, and structured errors/warnings without exposing PowerShell SDK types to the UI. Cancellation is propagated as normal .NET cancellation rather than being converted into a synthetic application state.

The application model intentionally remains partial at this stage. Manifest discovery supplies identity and descriptive metadata plus the declared provider identifier. Installed state, installed version, last-updated timestamp, icon, and update status remain unset/Unknown until authoritative Core-backed sources are available. In particular, the desktop layer does not call the private installed-state helper and does not infer `NotInstalled` from missing state.

The manifest schema currently provides a provider `pluginId`, not a human-friendly source name, so the presentation model records it as `SourceProviderId` rather than presenting the technical identifier as a display name.

Sorting and filtering are now represented by the presentation-only collection query boundary. List/Grid projection and WinUI binding remain downstream 11E work. No application update decision is made by the collection layer.

### Phase 11E application collection query

The collection query boundary keeps list presentation concerns separate from Core and from the loaded application models.

- `WintainiumApplicationQuery` carries the agreed Sort & Filter selections.
- `WintainiumApplicationCollectionQuery` applies those selections without changing application facts or making update decisions.
- The five sort choices are Name A–Z, Name Z–A, Update status, Installed status, and Source.
- The five filters are All software, Update available, Up to date, Installed, and Not installed.
- Filters for Installed/Not Installed and Update Available/Up to Date match only their explicit known states; `Unknown` is never treated as either known alternative.
- Sorting uses deterministic application-name and application-ID tie-breakers so presentation order is stable.
- The initial Unknown states remain visible to the presentation layer rather than being converted into a user-facing inference.
- The desktop EngineProbe covers all five sort choices and all five filters, including explicit checks that Unknown is not reclassified by filtering and remains first in the current status-sort presentation ordering.

### Phase 11E window lifetime hardening

The desktop shell now tracks every active WinUI window by `WindowId`, including the main window and the secondary Settings window. A tracked window is removed from the registry when its `Closed` event fires. This keeps the main and secondary window lifetimes explicit rather than relying on an incidental managed reference. The Settings window remains a secondary window and closing it must not terminate the Wintainium process while the main window remains open.
