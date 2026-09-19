# Wintainium Desktop

This project is the Phase 11 C#/.NET WinUI 3 presentation client foundation.

## Boundary

The desktop client is a presentation layer over the existing Wintainium.Core
PowerShell engine. It must consume documented public Core contracts and
structured results rather than reimplementing engine policy.

The intended dependency direction is:

Wintainium Desktop -> C# engine adapter -> Wintainium.Core public PowerShell API

The desktop project must not call private Core functions, providers, installers,
stage executors, or other internal orchestration components.

## Phase 11B scope

This foundation establishes:

- .NET 10 / WinUI 3 project structure.
- Windows App SDK dependency.
- x64 desktop target.
- WinUI application lifecycle entry point.
- Minimal window and application resource surface.
- An intentionally empty visual shell.

Window sizing, navigation, icons, title-bar treatment, tabs versus navigation,
application list/detail layout, settings layout, and other product-appearance
decisions remain deliberately outside 11B.

Packaging and release configuration will be established at the appropriate
later phase rather than being coupled to this foundation.
