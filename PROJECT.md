# Project Charter: Wintainium

## Mission

Wintainium is an open, modular Windows software manager that uses upstream
sources rather than depending primarily on a centralized package repository.

It is designed around a general lifecycle architecture:

**discover → decide → acquire → verify → install → reconcile → present**

## Core principles

1. **Manifests describe intent.** Application-specific configuration belongs in
   manifests, not hard-coded Core branches.
2. **Providers discover.** Providers translate upstream source mechanisms into
   normalized release/artifact observations.
3. **Core decides.** Update policy, artifact selection, installer selection,
   lifecycle sequencing, cancellation, and authoritative managed state remain
   Core responsibilities.
4. **Verification is mandatory.** Download success is not trust.
5. **Reconciliation establishes reality.** Post-install state is based on
   application-scoped evidence, not GUI assumptions.
6. **Presentation stays outside Core.** CLI and WinUI clients consume structured
   results without reproducing business rules.
7. **Fail safely.** Path boundaries, installer invocation, archive handling,
   verification, elevation, cancellation, and state persistence have explicit
   contracts.
8. **Prefer maintainable boundaries.** Do not add abstractions or speculative
   persistence merely because a future feature might need them.

## Current architecture

Wintainium consists of:

- **PowerShell Core** — authoritative engine and public operation boundary.
- **Provider plugins** — upstream source and release discovery.
- **Installer plugins** — EXE, MSI, portable ZIP, and MSIX application of
  selected artifacts.
- **Reconciliation plugin(s)** — authoritative Windows installed-application
  observations.
- **C#/.NET WinUI 3 desktop client** — presentation/application layer over Core.
- **JSON manifests and schemas** — application definitions and validation.

The desktop uses in-process Microsoft.PowerShell.SDK hosting, but PowerShell
SDK types stop at the adapter boundary. WinUI does not construct lifecycle
plans, provider requests, download requests, installer requests, reconciliation
requests, or private Core objects.

## Current product state

The Core lifecycle has been exercised against a real 7-Zip update, including
native installer elevation and authoritative post-install reconciliation.

Phase 13.5 production installers/package formats are complete.

Phase 14 GUI productization is in progress. The desktop currently includes:

- Dashboard application collection with list/grid presentation
- Sort/filter presentation
- Add Software source-URL onboarding
- structured onboarding success/failure/recovery presentation
- Application Details with operation status, lifecycle, errors/warnings,
  release information, and notes
- Check for Updates and Run Updates actions
- automatic application icon discovery plus user-selected icon override
- Remove Software from the Wintainium collection
- authoritative collection refresh after relevant operations

The Dashboard context menu intentionally exposes **Remove Software** only.
Opening Details by left-click already provides the application's full action hub;
redundant context-menu entries that merely opened Details are not part of the
current UX.

## Product boundary

Wintainium is no longer in a foundation/prototype stage. The engine, provider
boundary, acquisition, verification, installer boundary, reconciliation,
public update operation, onboarding boundary, and desktop integration exist.

Remaining work is primarily durability and productization:

- finish Phase 14 GUI polish and integration
- add persistent application lifecycle in Phase 15
- expand plugin ecosystem and extensibility in Phase 16
- harden reliability, security, recovery, and interrupted-operation behavior in
  Phase 17
- complete release engineering and 1.0 validation in Phase 18
