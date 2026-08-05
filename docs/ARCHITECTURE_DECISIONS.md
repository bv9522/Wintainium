# Architecture Decision Log

This log records architectural decisions that guide Wintainium's long-term
design. Decisions are immutable once accepted; a later decision may supersede
an earlier one with an explicit reference.

## Decision #001: PowerShell Engine with GUI Independence

**Decision:** The Wintainium engine will be PowerShell-first and usable
independently of any graphical interface.

**Reason:** The engine should support automation, scripting, scheduled tasks,
and future interfaces. A GUI should be a client of the engine, not the owner
of business logic.

**Status:** Accepted

## Decision #002: Managed Application as the Central Domain Entity

**Decision:** The Managed Application object is the central business concept
of Wintainium.

**Reason:** Users manage applications, not installers or providers. Provider
plugins and installer plugins are capabilities that serve the managed
application lifecycle.

**Alternatives considered:**

- Source-centric architecture
- Package-centric architecture

**Rejected because:** They couple Wintainium to specific distribution methods.

**Status:** Accepted

## Decision #003: Separate Provider and Installer Plugin Contracts

**Decision:** Wintainium will maintain separate plugin contracts for
discovering upstream release information and applying selected local
artifacts.

**Reason:** Release discovery and installation are fundamentally different
capabilities. A plugin that discovers software should not automatically have
installation privileges.

**Status:** Accepted

## Decision #004: Manifests declare management intent

**Decision:** Manifest files are declarative descriptions of management
intent.

**Reason:** Application definitions should remain portable and independent
from machine state.

**Constraints:** Manifests must not contain executable commands, installer
scripts, machine-specific paths, credentials, or bypasses of safety controls.

## Decision #005: Plugins communicate through the core

**Decision:** Provider and Installer plugins communicate only through the
Wintainium core.

**Reason:** The core owns workflow orchestration, policy enforcement, and
state management. Plugins provide capabilities but do not control lifecycle
decisions.

## Decision #006: Phase 1 Validation Baseline

**Decision:** Phase 1 uses PowerShell 7.4 LTS, JSON Schema Draft 2020-12, and
the Pester framework to validate application definitions offline.

**Reason:** A stable runtime and schema dialect make manifest validation
reproducible, while offline tests prove the internal architecture before
external provider or installer complexity is introduced.

**Status:** Accepted
