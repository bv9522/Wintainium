# Architecture

## Boundary

The PowerShell engine owns discovery, trust evaluation, validation, downloads,
installation coordination, configuration, and logging. A future GUI is a
client of that engine and must not duplicate engine rules.

## Main components

| Component | Responsibility |
| --- | --- |
| Core | Public commands, contracts, orchestration, shared validation, and error handling. |
| Provider plugins | Discover upstream release and artifact metadata through the provider contract. |
| Installer plugins | Validate and apply a downloaded artifact according to its format. |
| Application manifests | Declare portable application-management intent and select compatible plugins. |
| Manifest repositories | Store and distribute Wintainium application manifests. |
| Configuration | Holds user-selected paths, policies, and enabled plugins. |

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
- Provider descriptors declare stable identity, contract versions, and capabilities; they do not contain arbitrary executable instructions.

## Provider contract

Phase 3 establishes a versioned provider contract. Provider Contract Version
`1` requires provider descriptors to declare `releaseDiscovery=true` and
`artifactDiscovery=true` capabilities.

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

Provider-specific API fields remain inside the provider implementation unless
a future architecture decision deliberately promotes a field into the Core
model. Artifact URIs, hashes, and signatures are untrusted source metadata;
verification is a later Core responsibility.

Provider operations may communicate with upstream network services. The Phase
2 Manifest Engine remains completely network-free and must never invoke a
provider during manifest discovery or import.

Provider results distinguish successful discovery with no matching releases
from provider/source failures. Core-level provider resolution failures such as
unregistered providers, incompatible contracts, and unsupported capabilities
are distinct from upstream failures such as source unavailability or
authentication failure.

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
