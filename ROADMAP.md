# Wintainium Roadmap

Wintainium has moved from architecture proof into productization. The real
7-Zip update validated the general lifecycle boundary end to end, including
verification, native installer execution/elevation, and authoritative
post-install reconciliation.

## Completed foundations

### Phases 1–8 — Engine foundation, providers, acquisition, installers, orchestration, public contracts

Complete and locked. These phases established manifest validation and
discovery, provider contracts, update decisions, download safety, verification,
installer selection/invocation, lifecycle orchestration, public structured
results, packaging, upgrade boundaries, and GUI readiness.

### Phase 9 — Complete Update Lifecycle

**Complete and locked.**

The Core-owned lifecycle now spans:

Manifest Validation → Release Discovery → Update Decision → Download →
Verification → Installer Selection → Installation → Reconciliation.

Authoritative managed installed state remains Core-owned.

### Phase 10 — Public Application Update Contract

**Complete and locked.**

The complete lifecycle is exposed through a stable public
`Invoke-WintainiumApplicationUpdate` boundary without leaking private
orchestration objects to callers.

### Phase 11 — C#/.NET GUI Foundation and Desktop Client

**Complete and locked.**

Established the WinUI 3 desktop client, in-process PowerShell hosting,
application models and collection/query boundaries, Details, operation
presentation, cancellation, settings foundation, and focused desktop
integration hardening.

### Phase 12 — Desktop/Core Integration

**Complete and locked.**

Connected the desktop client to the public Core boundaries, including
application collection, validation, release discovery, installed-state
observation, update status, onboarding, and operation result presentation.

### Phase 13 — GUI Polish / Productization foundation

**Complete and superseded by Phase 14.**

The GUI moved from integration scaffolding toward a coherent product surface:
Dashboard/list-grid presentation, Details, application identity, update state,
and collection actions.

### Phase 13.5 — Production Installers

**Complete and locked.**

Production packaging/installers are established for EXE, MSI, portable ZIP,
and MSIX, with the required protections and regression coverage.

## Phase 14 — GUI Productization

**Current phase — in progress.**

The objective is to turn the existing desktop client into a coherent,
production-quality Wintainium application without moving engine authority into
WinUI.

### 14E — Add Software / Onboarding UX

- polish source URL entry
- present source-resolution activity and results clearly
- handle unsupported, ambiguous, unavailable, interactive, authentication,
  and failure states
- provide useful recovery actions
- preserve correct discovered application identity/display name
- transition naturally into the Dashboard collection
- keep provider/Core internals out of the UX
- avoid implying that the source page itself must contain all verification
  evidence

### 14F — Update Experience

- present Core lifecycle activity before/after native installer execution
- clearly communicate native installer/elevation transitions
- present lifecycle results, errors, warnings, and cancellation
- do not invent Wintanium-owned installer progress percentages
- refresh authoritative installed state after installation
- make update state/action availability reflect real Core state

### 14G — Settings Productization

- General
- Appearance
- Updates
- Sources
- Advanced
- connect settings only to real supported configuration
- no fake persistence or speculative controls

### 14H — Visual System

- Windows 11/System/Light/Dark behavior
- Wintanium visual language
- typography, spacing, cards, icons, dialogs, empty states
- Y2K / Frutiger Aero influence where appropriate
- automatic application icons plus optional user-selected overrides

### 14I — GUI Accessibility & Interaction Audit

- keyboard navigation and focus
- accessibility/automation properties
- resizing and High-DPI behavior
- theme behavior
- disabled/enabled states
- error and empty-state accessibility
- UAC transitions
- focus restoration after dialogs/native installers

### 14J — Phase 14 Integration & Lock

- full desktop regression
- full PowerShell regression
- real onboarding
- real installation/update
- reconciliation validation
- UAC/elevation
- failure and cancellation paths
- architecture audit
- UX audit
- repository/build cleanup
- Phase 14 lock

## Phase 15 — Persistent Application Lifecycle

### 15A — Persistent application configuration
- durable application-definition collection
- persist Wintanium-owned metadata
- durable state across restarts/upgrades
- schema/config migration

### 15B — Persistent user preferences
- persistent settings/defaults
- preference migration
- keep user preferences separate from engine-managed application state

### 15C — Application collection lifecycle
- startup loading
- add/remove/refresh
- stale or invalid configuration handling
- recovery behavior

### 15D — Application removal
- distinguish Remove from Wintainium from Uninstall application
- use Core/installer contracts for uninstall if that capability is introduced

### 15E — Update policy completion
- Do Not Update
- policy persistence
- Core enforcement at the decision boundary

### 15F — Scheduling / automatic updates
- scheduling
- background execution
- cancellation and failure handling
- user-visible status/history

### 15G — Lifecycle integration proof

Onboard → Discover → Install → Reconcile → Persist → Restart → Load persisted
state → Detect update → Download → Verify → Install → Reconcile → Persist
authoritative state

### 15H — Phase 15 Lock

## Phase 16 — Plugin Ecosystem & Extensibility

- plugin management
- provider/installer/reconciliation ecosystem
- plugin contract/version validation
- contributor documentation
- extensibility audit
- Phase 16 lock

## Phase 17 — Reliability, Security & Recovery

- interrupted downloads and installs
- crash/restart recovery
- interrupted update recovery
- transaction boundaries
- resource/process lifecycle
- logging and diagnostics
- security audit
- recovery semantics

## Phase 18 — Release Engineering & Wintainium 1.0

- versioning
- production Wintainium installer
- self-upgrade
- clean-machine validation
- release candidate
- final regression/security/UX audit
- Wintainium 1.0 lock
