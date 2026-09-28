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
download, verification, installation, Windows installed-application
reconciliation, authoritative installed-state handling, and complete lifecycle
orchestration. Production installer capabilities currently include EXE, MSI,
portable ZIP, and MSIX. The public PowerShell surface now exposes six stable commands, including the
installed-state, onboarding, and end-to-end update operations and their
presentation-neutral structured result contracts.

## Current product boundary

The PowerShell engine remains the primary product and is intended to be usable
without a GUI. Public commands return structured results suitable for an
interactive CLI presentation layer or a future C#/.NET client. Presentation
formatting and UI concerns remain outside Core.

The Phase 11 desktop client is the implemented C#/.NET WinUI 3 presentation client over that boundary. It hosts the documented PowerShell Core commands in-process through Microsoft.PowerShell.SDK, maps structured results into desktop presentation models, and keeps engine decisions, provider/installer behavior, lifecycle execution, verification, reconciliation, and cancellation semantics in Core.


## Production plugin boundary

The current production architecture separates discovery, decision, acquisition,
verification, installation, reconciliation, and presentation:

- Providers discover upstream releases and artifact candidates.
- Core decides release/update eligibility, artifact selection, and installer
  selection.
- Download obtains the selected artifact.
- Verification establishes artifact trust before installation.
- Installer plugins apply artifacts through a structured invocation boundary.
- The Windows reconciliation plugin observes installed-application evidence.
- Core remains authoritative for managed installed state.
- The WinUI desktop client presents Core-owned results and does not become a
  second engine.

The production installer set is EXE, MSI, portable ZIP, and MSIX. The default
installer mechanism preference is Core policy and can be constrained by a
manifest; it is not an application-universal hard-coded ranking.

Plugin descriptor validation protects contract integrity but is not a sandbox.
Production plugin modules are trusted executable code and run in-process.
Structured process arguments, path containment, archive traversal checks, and
fixed MSIX invocation reduce concrete command-boundary risks without claiming
isolation from malicious plugin code.
