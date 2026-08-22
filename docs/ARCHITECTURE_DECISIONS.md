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

## Decision #007: Local Manifest Discovery Is Separate From Upstream Release Discovery

**Decision:** The Phase 2 Manifest Engine treats local manifest discovery and
import as a distinct offline capability from provider-based upstream release
discovery.

**Reason:** A manifest repository distributes management definitions, while a
provider discovers release and artifact metadata from an upstream software
source. Conflating these operations would introduce network behavior and
provider execution into a layer that must remain deterministic and locally
validatable.

**Constraints:** Local discovery/import must not download, execute, or contact
network services. Future remote catalog functionality must adapt external
sources to the manifest-engine boundary rather than changing this local
contract.

**Status:** Accepted

## Decision #008: Recognized Manifest Files Use an Explicit Filename Convention

**Decision:** Wintainium recognizes `*.wintainium.json` files as manifest
candidates. Arbitrary JSON files are not implicitly treated as manifests.

**Reason:** Collections commonly contain metadata, documentation, and other
JSON. An explicit filename convention prevents accidental interpretation of
unrelated data while making collection discovery predictable.

**Status:** Accepted

## Decision #009: Duplicate Application IDs Are Collection Errors

**Decision:** A collection containing multiple valid manifests with the same
application ID is considered erroneous. Core returns the valid manifests but
does not silently choose a winner.

**Reason:** Deterministic discovery order is useful for reproducibility, but
order must not become an implicit precedence rule for application identity.
A later catalog or policy layer can define explicit precedence if needed.

**Status:** Accepted

## Decision #010: Phase 2 Public/Private Manifest Boundary

**Decision:** `Get-WintainiumManifest` is the public local collection command.
`Import-WintainiumManifest` remains private and is the single-manifest import
primitive used by Core.

**Reason:** Callers need a stable collection-level contract, while the
implementation should retain freedom to change the internal import pipeline
without exposing implementation details as public API.

**Status:** Accepted
