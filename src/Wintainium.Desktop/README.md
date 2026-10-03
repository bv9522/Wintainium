# Wintainium Desktop

This project is the production Phase 14 WinUI 3 desktop client over the
Wintainium.Core PowerShell engine.

## Boundary

The dependency direction is:

```
Wintainium Desktop
        ↓
C# application/engine adapter
        ↓
Wintainium.Core public PowerShell API
```

The desktop must not call private Core functions, providers, installers,
reconciliation implementations, or orchestration stages directly.

Core owns lifecycle and policy. The desktop owns presentation, interaction,
window lifetime, and mapping structured Core results into user-facing models.

## Current Phase 14 product surface

The Dashboard is the application's main collection surface.

- List/Grid presentation
- Sort and Filter presentation
- Add Software in the Dashboard
- application identity and installation/update state
- application icons
- right-click Remove Software action
- left-click opens Application Details

The Dashboard context menu intentionally contains **Remove Software** only.
Do not add Change Icon or Update entries merely to open Details; those actions
are already available from the Details hub reached by left-click.

### Add Software

Add Software accepts a source URL and calls
`Invoke-WintainiumApplicationOnboarding` through the Core adapter.

Core owns:

- source URI validation
- provider discovery and source resolution
- ambiguity/unsupported/authentication/interactive handling
- default lifecycle-policy resolution
- application normalization
- manifest persistence

The desktop presents the structured result and provides appropriate recovery
actions. It does not construct provider, installer, reconciliation, or lifecycle
policy objects.

### Application Details

Details is the per-application action and information hub.

It currently presents:

- application information
- installation state and installed version
- update status
- source/provider information
- update policy placeholder
- operation status
- lifecycle stages
- errors and warnings
- release information
- notes
- Check for Updates
- Run Updates
- automatic icon presentation
- user-selected icon override
- Reset to Automatic icon behavior

The Do Not Update policy control remains intentionally reserved until durable
policy/configuration support is implemented.

### Icons

Automatic icon metadata and user-selected icon overrides are separate.

Selecting a custom icon does not destroy the automatically discovered icon.
Resetting the override returns presentation to automatic behavior.

### Removal

Remove Software removes the application's managed definition from the
Wintainium collection. It does not uninstall the Windows application.

The Core `Remove-WintainiumApplication` boundary owns safe collection-root
validation and manifest removal.

## Update experience

The desktop must not invent quantitative installer progress.

For native installers, Wintainium presents lifecycle/activity before and after
the installer boundary, communicates elevation where appropriate, and refreshes
authoritative installed state after completion. The native installer owns its
own installer UI.

## Architecture rules

- Do not move lifecycle/policy/provider/installer/reconciliation logic into C#.
- Do not infer installed or update state from missing data.
- Do not parse console output as an API.
- Preserve Core-owned OperationId and cancellation semantics.
- Treat structured result codes and documented fields as the integration
  contract.
- Keep PowerShell SDK types below the adapter boundary.

## Development

Preferred Release build:

```powershell
dotnet build .\src\Wintainium.Desktop\Wintainium.Desktop.csproj -c Release
```

The desktop targets .NET 10 / WinUI 3 and hosts Wintainium.Core in-process
through Microsoft.PowerShell.SDK.
