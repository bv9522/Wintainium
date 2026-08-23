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

## Decision #011: Provider Contract Discovers Releases and Artifact Candidates

**Decision:** A provider discovers upstream releases and the artifact
candidates associated with those releases. It does not select the final
release or final artifact for Wintainium.

**Reason:** Provider-specific upstream knowledge must remain separate from
Core lifecycle policy. Core may later consider installed state, manifest
preferences, architecture, installer compatibility, trust policy, and other
constraints when selecting a release and artifact.

**Status:** Accepted

## Decision #012: Provider Results Use Normalized Core Models

**Decision:** Provider results expose only provider-independent Wintainium
release and artifact concepts. Provider-specific API fields remain inside the
provider implementation unless deliberately promoted by a future architecture
decision.

**Reason:** An unrestricted provider-metadata bag would create an undocumented
second Core schema and couple future phases to individual upstream services.

**Status:** Accepted

## Decision #013: Provider Contract Uses Major Version Compatibility

**Decision:** Provider Contract Version 1 uses positive major-version
identifiers such as `"1"`. A manifest requires a specific provider contract
major version through `source.requiredContractVersion`, and a provider must
explicitly advertise that version in `contractVersions`.

**Reason:** The existing plugin descriptor and manifest contracts already use
major-version identifiers. Keeping the same mechanism avoids introducing an
incompatible versioning system. Breaking provider-contract changes require a
new major contract version.

**Status:** Accepted

## Decision #014: Provider Descriptors Do Not Contain Arbitrary Executable Instructions

**Decision:** Provider descriptors identify provider identity, supported
contract versions, capabilities, and a constrained relative module entry
point. They do not contain arbitrary PowerShell commands, script expressions,
or manifest-controlled executable instructions.

**Reason:** Provider execution is controlled by the plugin system and Core.
The entry point is a constrained file reference to a PowerShell module, while
the operation Core invokes is fixed by the provider contract.

**Status:** Accepted

## Decision #015: Provider Network Boundary

**Decision:** Provider operations may communicate with declared upstream
software sources. The Phase 2 Manifest Engine remains completely network-free.

**Reason:** Network behavior belongs at the provider boundary. Keeping it out
of manifest discovery and import preserves deterministic offline validation
and prevents provider execution from being triggered accidentally.

**Status:** Accepted

## Decision #016: Provider Results Distinguish No Data From Failure

**Decision:** `NoReleasesFound` is distinct from source availability,
authentication, configuration, malformed upstream data, provider-result
validation, and provider-internal failures.

**Reason:** Update discovery and diagnostics require Core to distinguish a
healthy source containing no matching releases from an operation that could
not reliably obtain release information.

**Status:** Accepted

## Decision #017: Provider Operation Uses a Fixed Module Contract

**Decision:** A provider plugin entry point is a constrained relative `.psm1`
module path. Core invokes only the fixed exported operation
`Invoke-WintainiumProvider -Request <ProviderRequest>`.

**Reason:** Providers are executable behavior, but arbitrary command selection
would create an unnecessary execution surface. A fixed operation gives
providers implementation freedom inside their module while keeping the Core
boundary deterministic and auditable.

**Status:** Accepted

## Decision #018: Provider Operation Returns Exactly One Structured Result

**Decision:** A provider operation must return exactly one `ProviderResult`.
Core validates the result before accepting its normalized release and artifact
data.

**Reason:** A single structured result prevents provider output streams from
becoming an implicit second protocol and gives Core one deterministic boundary
for success, no-data, warnings, and failures.

**Status:** Accepted

## Decision #019: Core Owns Provider Result Validation

**Decision:** Core validates provider result structure, correlation identity,
and normalized release shape. Provider-specific data is not accepted into the
Core model merely because a provider emitted it.

**Reason:** Providers are replaceable executable plugins. Core must enforce the
shared contract rather than trusting each implementation to define its own
interpretation of valid output.

**Status:** Accepted

## Decision #020: Provider Exceptions Become Structured Operation Failures

**Decision:** Unhandled provider execution exceptions are converted by Core
into structured `ProviderInternalError` results. Provider-returned statuses
such as `NoReleasesFound` remain provider-defined structured outcomes rather
than exceptions.

**Reason:** Expected operational failures must remain machine-readable and
correlated. Exceptions crossing the plugin boundary would make provider
behavior inconsistent and complicate later orchestration.

**Status:** Accepted

## Decision #021: Provider Architecture Is Source-Agnostic; GitHub Is the First Reference Provider

**Decision:** Wintainium's provider contract must remain independent of any
single upstream distribution platform. GitHub Releases is the first real
reference provider, while future providers may target official vendor
websites, vendor APIs, feeds, CDNs, update manifests, and other authoritative
sources.

**Reason:** Wintainium's mission is to obtain software from official developer
sources rather than depend primarily on a centralized repository. Many Windows
applications are not distributed through GitHub. Making GitHub-specific
concepts part of Core would undermine the project's central extensibility goal.

**Constraints:** GitHub-specific API fields remain inside the GitHub provider.
Core consumes only normalized provider-independent release and artifact data.
A new source family must be implementable as another Provider Contract v1
plugin without changing the Core provider operation boundary solely because of
that source's transport or API.

**Status:** Accepted
