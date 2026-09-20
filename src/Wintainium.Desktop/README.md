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
  infer Unknown as Not installed.

The shell intentionally uses placeholder collection/settings content. Later
Phase 11 batches will replace those placeholders with real presentation models
and Core-backed behavior.

## Phase 11D engine integration boundary

11D establishes the C#-to-PowerShell boundary without wiring business operations
into the WinUI controls.

- WintainiumPowerShellHost owns in-process Microsoft.PowerShell.SDK hosting,
  runspace creation, scoped hosted execution policy, Core module import, serialized
  invocation, and cancellation-triggered pipeline stopping.
- WintainiumCoreClient exposes only the four documented public Core commands:
  Get-WintainiumManifest, Test-WintainiumApplicationDefinition,
  Get-WintainiumApplicationRelease, and Invoke-WintainiumApplicationUpdate.
- The adapter passes documented command parameters through to Core and does not
  construct private lifecycle, stage, provider, installer, download, or
  reconciliation objects.
- WintainiumPowerShellInvocationResult is the adapter-local transport boundary;
  PowerShell SDK types remain below the application-facing adapter seam.
- The WinUI shell does not yet invoke the adapter. Application models and UI
  behavior will be connected in later Phase 11 batches.
- The PowerShell SDK is hosted in-process; terminal output is never used as an API.

## Scope discipline

11C establishes the product shell and interaction locations. It does not
finalize every visual detail or implement speculative downstream functionality.

11D establishes the engine integration seam. It does not migrate engine policy
to C#, expose private Core functions, or prematurely build application models,
progress UI, settings persistence, or update workflows into the shell.
