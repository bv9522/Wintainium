# Architecture

## Boundary

The PowerShell engine owns discovery, trust evaluation, validation, downloads,
installation coordination, configuration, logging, and lifecycle policy. The
C#/.NET WinUI desktop client is a presentation client of that engine and must
not duplicate engine rules.

Configuration is an engine responsibility, but the current public contract does
not yet expose a general-purpose configuration command or persistence surface.
The concrete configuration/state boundary is intentionally deferred to the
appropriate later phase rather than being implied by this architectural
statement.

## Main components

| Component | Responsibility |
| --- | --- |
| Core | Public commands, contracts, orchestration, shared validation, and error handling. |
| Provider plugins | Discover upstream release and artifact metadata through the provider contract. |
| Installer plugins | Validate and apply a downloaded artifact according to its format. |
| Application manifests | Declare portable application-management intent and select compatible plugins. |
| Manifest repositories | Store and distribute Wintainium application manifests. |
| Configuration | Holds user-selected paths, policies, and enabled plugins when that configuration surface is established. |

## Repositories and providers

A **manifest repository** is a location that stores Wintainium manifest files.
It distributes management definitions; it is not necessarily related to an
application publisher.

An **upstream software provider** is the official developer, vendor, service,
or location from which a provider plugin discovers release and artifact
metadata. Examples include GitHub Releases, a vendor API, a local repository,
or a future Microsoft Store integration.

These are separate concepts. A manifest can be distributed from one manifest
repository while its provider plugin discovers releases from a different
upstream software provider.

## Plugin design rules

- Plugins expose a small documented contract and return structured objects.
- Plugins do not directly depend on one another.
- Core does not contain vendor- or application-specific branching.
- A manifest selects provider and installer plugins by stable identifiers.
- Plugin failures produce actionable errors and leave state recoverable.
- Provider and installer plugins communicate only with the core.
- Provider descriptors declare stable identity, contract versions, capabilities, and constrained module entry points; they do not contain arbitrary executable commands.

## Provider contract

Phase 3 establishes a versioned provider contract. Provider Contract Version
`1` requires provider descriptors to declare `releaseDiscovery=true` and
`artifactDiscovery=true` capabilities and a relative `.psm1` entry point.

The Core-to-provider operation is fixed: Core loads the validated provider
module and invokes only `Invoke-WintainiumProvider -Request <ProviderRequest>`.
The descriptor cannot select an arbitrary command. The provider operation is
private to Core and returns exactly one structured `ProviderResult`.

A provider receives a purpose-built discovery request rather than the entire
application manifest. The request contains Core correlation information,
application/provider identity, the required provider contract version,
validated non-secret provider settings, and narrowly scoped discovery context.

A provider discovers upstream releases and the artifact candidates associated
with those releases. It does **not** select the final release or artifact,
perform update determination, download an artifact, verify downloaded bytes,
or install anything. Those responsibilities remain with later Core phases.

Normalized provider results contain only provider-independent Wintainium
concepts. A release contains an opaque release identifier, upstream version
string, normalized channel, optional publication timestamp, and artifact
candidates. An artifact may contain an untrusted URI, filename, normalized
format, normalized architecture, optional size, upstream-declared hashes, and
upstream-declared signature metadata.

Core validates provider result structure, operation correlation, and normalized
release shape before accepting provider data. Provider-specific API fields
remain inside the provider implementation unless a future architecture
decision deliberately promotes a field into the Core model. Artifact URIs,
hashes, and signatures are untrusted source metadata; verification is a later
Core responsibility.

Provider operations may communicate with upstream network services. The Phase
2 Manifest Engine remains completely network-free and must never invoke a
provider during manifest discovery or import.

Provider results distinguish successful discovery with no matching releases
from provider/source failures. Core-level provider resolution failures such as
unregistered providers, incompatible contracts, and unsupported capabilities
are distinct from upstream failures such as source unavailability or
authentication failure. Unhandled provider exceptions crossing the operation
boundary are represented as structured `ProviderInternalError` results.

See `core/Wintainium.Core/Contracts/ProviderContract.md` for the detailed
contract and `docs/ARCHITECTURE_DECISIONS.md` for the accepted decisions.

## Trust and validation

Download URLs, release metadata, and artifacts are treated as untrusted input.
The core evaluates trust, validates downloaded artifacts, evaluates checksums
and signatures when available, enforces safety policy, and requires user
approval when appropriate. Manifests express application intent and acceptable
artifact preferences only; they do not make trust decisions or bypass safety
controls.

The core validates expected file types and destination paths before
installation. User data must never be overwritten implicitly.

## Manifest Engine contracts

Phase 2 establishes a deliberately local and offline manifest engine. Manifest
discovery, import, JSON parsing, and schema validation do not perform network
access, download artifacts, execute commands, or invoke provider or installer
behavior.

### Manifest file convention

Recognized manifest files use the `*.wintainium.json` filename convention.
Ordinary JSON files are not implicitly treated as Wintainium manifests.
Collections are local directories. Discovery is non-recursive by default and
supports explicit recursive discovery through `Get-WintainiumManifest -Recurse`.
Candidate paths are returned in deterministic full-path order.

### `Get-WintainiumManifest`

`Get-WintainiumManifest` is the public Core command for discovering and
collecting local manifests. It accepts a mandatory directory `-Path`, an
optional `-Recurse` switch, and an optional `-SchemaPath` override.

The command returns one structured result object with this stable shape:

| Property | Meaning |
| --- | --- |
| `OperationId` | Correlation identifier for the operation and its log events. |
| `IsSuccessful` | `true` only when discovery/import completed without errors. |
| `Candidates` | Recognized manifest file paths discovered in deterministic order. |
| `ManifestPaths` | Paths corresponding to successfully imported manifests. |
| `Manifests` | Successfully imported internal manifest models. |
| `Errors` | Structured errors encountered during collection or import. |
| `Warnings` | Structured warnings returned by the manifest engine. |
| `LogEvents` | Structured Core log events associated with the operation. |

A malformed or schema-invalid candidate does not prevent other valid candidates
from being returned. Duplicate application IDs are reported as collection
errors; Core does not silently select a winner. An empty recognized collection
is a successful operation.

### `Import-WintainiumManifest`

`Import-WintainiumManifest` is a private Core operation used to import one
local manifest. It accepts a manifest `-Path` and optional `-SchemaPath` and
returns a structured result containing `IsValid`, `Path`, `Manifest`, `Errors`,
and `Warnings`.

Import distinguishes missing files, invalid directory paths, read failures,
malformed JSON, schema-invalid manifests, and unavailable schema resources.
A valid document is converted into the internal manifest model only after
schema validation succeeds.

### Internal manifest model

The current internal manifest model contains:

`ManifestVersion`, `Id`, `Name`, `Description`, `Homepage`, `Publisher`,
`Aliases`, `Documentation`, `Notes`, `Deprecated`, `Source`, `Installer`,
`Release`, and `Artifact`.

The model remains declarative. Provider and installer references identify
capabilities but do not cause plugin execution during manifest import or
collection.

### Error and logging conventions

Manifest operations return structured results rather than relying on
exceptions for expected validation or collection failures. Errors contain a
stable `Code`, `Path`, and human-readable `Message`. Public collection
operations expose an `OperationId` and structured `LogEvents` for correlation.

These Phase 2 contracts are intentionally independent from future remote
catalogs. A future remote catalog layer may obtain manifest documents from
network sources, but it must supply validated manifest documents to the same
manifest-engine boundary rather than adding networking to local discovery or
import.

## Phase boundaries

The Manifest Engine does not perform release discovery, downloading,
installation, or update decisions. Provider release/artifact discovery begins
at Phase 3. Update decisions belong to Phase 4; downloading to Phase 5;
installation to Phase 6; and lifecycle orchestration to Phase 7.

### Phase 4 update determination (locked)

Phase 4 converts validated manifest policy, installed application state, and a
completed normalized provider result into a deterministic, explainable update
decision. Core owns version comparison, release eligibility, artifact
selection, target resolution, and the final structured result.

Providers discover upstream releases and artifacts; they do not make
application-specific update decisions. Provider metadata remains untrusted
observation data throughout Phase 4. Ambiguous ordering, unavailable provider
data, and incompatible artifacts are represented as structured outcomes rather
than guessed selections.

Phase 4 decides **what** update target, if any, should be considered. It does
not download data, verify downloaded bytes, choose an installer, or execute an
installation. Those responsibilities begin in Phases 5 and 6.


## Installer architecture

Installer plugins are execution capabilities, not application-specific policy.
The production Contract 1 installer set currently contains four implementations:

| Plugin | Formats | Installation mode |
| --- | --- | --- |
| Wintainium.installer.exe | exe | process |
| Wintainium.installer.msi | msi | process |
| Wintainium.installer.portable-zip | zip | archive |
| Wintainium.installer.msix | msix | package |

Core owns installer selection. A manifest may explicitly identify an installer
plugin; in that case Core resolves that exact plugin, validates its Contract 1
compatibility, and requires the selected artifact format to be supported by
that plugin. Core does not silently switch to a different installer because
another format is available.

When a manifest uses the Core-owned default application policy, the default
mechanism preference is exe, msi, msix, then zip, subject to registered
Contract 1 plugins and the manifest's declared capabilities. This is policy,
not a universal installer ordering: application-specific manifest policy can
constrain acceptable formats, and an explicitly selected installer remains
authoritative.

Artifact selection and installer selection are separate decisions. Core first
selects an eligible artifact using architecture and manifest format policy;
installer selection then verifies that the selected artifact can be handled by
the declared or policy-selected installer. Architecture compatibility takes
priority over format preference. The normal architecture preference is exact
machine architecture, then neutral, then explicitly allowed unknown
architecture. x64 and x86 registry/platform concepts remain distinct.

Installer plugins receive a downloaded artifact through a structured Core
boundary. EXE and MSI installers return structured process specifications
rather than shell command strings. The portable ZIP installer returns a
constrained archive-installation process specification and requires an
absolute destination path; an optional archive entry point must remain a
relative, non-traversing path. The MSIX installer uses the system Windows
PowerShell executable with settings serialized as JSON arguments rather than
interpolated into a command string.

Before an installer module is loaded, Core revalidates the descriptor and
binds its plugin identity, plugin type, and declared entry point to the
selection. Plugin entry points must resolve to absolute existing .psm1 files
inside the selected plugin root. Duplicate plugin identities are rejected
rather than resolved by path order.

Descriptor validation establishes plugin identity, contract, capability, and
entry-point integrity. It is not a sandbox. Production plugin modules are
trusted executable code and run in-process under the Core process. The
structured process boundary limits command/argument ambiguity for child
processes, but it does not turn arbitrary plugin code into untrusted sandboxed
code.

## Installation and reconciliation boundary

Installation and reconciliation answer different questions. The installer
applies the selected artifact. The Windows installed-application reconciliation
plugin observes Windows uninstall evidence and reports normalized installation
evidence. Reconciliation does not replace the installer subsystem and does not
become a second authoritative managed-state store.

A reconciliation result may establish an installed/not-installed observation or
remain Unknown when evidence is insufficient or ambiguous. Core does not
silently choose among multiple matching Windows uninstall records. Matching is
case-insensitive and exact against the application identity contract. Windows
registry evidence from current-user/machine and 64-bit/32-bit registry views is
handled as distinct evidence sources; architecture is not inferred merely
from the existence of a particular registry view.

## Plugin trust boundary

Wintainium's plugin architecture is extensible, but plugin extensibility is not
a security sandbox. Core validates descriptors, contract versions, capabilities,
entry-point shape, plugin identity, and structured operation results. It also
validates installer invocation inputs and process specifications before
execution. Those controls protect the Core contract and reduce malformed-input
and command-boundary risks; they do not establish isolation from malicious
plugin code. Plugin installation and distribution therefore remain a trusted
administrative boundary.

The architectural flow remains:

**Manifest describes → Provider discovers → Core decides → Download obtains → Verification establishes trust → Installer applies → Reconciliation observes → Orchestration coordinates → UX presents.**
