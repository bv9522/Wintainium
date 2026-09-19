# Project Charter: Wintainium

## Mission

Wintainium is an open, modular Windows software manager that uses official
developer sources instead of depending primarily on centralized repositories.

## Principles

1. Keep the architecture modular; application-specific behavior belongs in
   manifests or plugins, not the core.
2. Prefer official sources: GitHub Releases, vendor sites, feeds, and vendor
   APIs. Package-manager integrations are optional.
3. Keep the engine usable without a GUI.
4. Favor readable, maintainable PowerShell over clever shortcuts.
5. Fail safely: validate practical downloads, avoid overwriting user data
   without explicit policy, and log important operations.

## Initial technology choices

- Engine: PowerShell
- Configuration and manifests: JSON
- Future GUI: C#/.NET, separate from the engine
- Version control: Git

## Foundation-phase non-goals

The original foundation phase deliberately excluded update-checking,
installation, network source integrations, and GUI implementation. Those
constraints applied to the early architecture work and are no longer a
statement of the project's current capability boundary.

The implemented engine now includes provider-backed release discovery,
download, installation, reconciliation, authoritative installed-state
handling, and complete lifecycle orchestration. The public PowerShell surface
now exposes four stable commands, including the end-to-end
Invoke-WintainiumApplicationUpdate operation and its presentation-neutral
structured result contract.

## Current product boundary

The PowerShell engine remains the primary product and is intended to be usable
without a GUI. Public commands return structured results suitable for an
interactive CLI presentation layer or a future C#/.NET client. Presentation
formatting and UI concerns remain outside Core.
