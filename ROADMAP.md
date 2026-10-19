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

### 14C — Navigation & Presentation Acceptance

Focused acceptance of the existing Dashboard rather than a presentation rewrite:

- list/grid presentation and sort/filter behavior
- selection and navigation into Details
- empty states and application identity/state
- installed/update status and version presentation without clipping
- Remove Software semantics: remove from Wintainium's collection, not uninstall

### 14D — Application Details Acceptance

Focused acceptance of the existing Details window:

- identity, icon, installation/update state, and release information
- install, update-check, and update action availability from authoritative state
- lifecycle stages, results, warnings, failures, cancellation, and diagnostics
- authoritative installed-state reconciliation and Dashboard refresh
- cancellation must not suppress post-operation reconciliation

### 14E — Add Software / Onboarding UX

**Complete.** Source URL onboarding presents resolution outcomes and recovery
paths, handles unsupported/ambiguous/unavailable/interactive/authentication and
failure states, preserves discovered identity, transitions into the collection,
and keeps provider/Core internals out of the UX. Verification evidence may be
discovered independently of the supplied source page.

### Phase 14.5 — First-Install Capability

**Complete and locked.** The public Core install operation, artifact selection,
shared lifecycle orchestration, native installer/elevation handling, structured
results, authoritative reconciliation, and desktop Install action are integrated.
The implementation reuses the existing lifecycle engine; it does not create a
parallel installer architecture.

The historical installer and artifact test counts recorded in commit-era reports
are not a claim that those suites have been rerun at the current branch head.

### 14F — Update Experience

**Current engineering focus.**

- present Core lifecycle activity before/after native installer execution
- clearly communicate native installer/elevation transitions
- present lifecycle results, errors, warnings, and cancellation
- do not invent Wintanium-owned installer progress percentages
- reconcile authoritative installed state after install/update, including
  cancellation paths where an operation may already have changed the machine
- make update state/action availability reflect real Core state
- verify Dashboard and Details refresh consistency
- confirm operation cancellation does not cancel the follow-up reconciliation

### 14G — Settings Productization

- audit existing General, Appearance, Updates, Sources, and Advanced categories
- keep Appearance controls connected to the existing visual-style/theme system
- connect only settings with a real, observable consumer
- verify confirmation settings against actual install/update/remove flows
- defer launch-at-sign-in until startup integration exists
- defer automatic checking/frequency and auto-install until durable scheduling
  and lifecycle policy are implemented
- defer notifications unless the corresponding notification behavior exists
- keep Sources/Advanced explicit about unavailable capabilities; no fake controls

### 14H — Visual System

**Complete and frozen.** Windows 11 Bliss Light/Dark, Y2K Light/Dark, Frutiger
Aero Light/Dark (including Frutiger Metro), typography, backgrounds, title bars,
dialogs, icons, and theme isolation have been implemented. Reopen only for a
reproducible defect; do not make aesthetic changes or allow cross-theme bleed.



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
