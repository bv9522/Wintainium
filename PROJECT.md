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

## Non-goals for the foundation phase

- No update-checking or installation logic
- No network source integrations
- No GUI implementation
