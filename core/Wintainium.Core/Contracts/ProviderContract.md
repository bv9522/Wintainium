# Provider Contract

## Status

Phase 3A contract: Accepted.

Provider Contract Major Version: `1`.

## Purpose

A Wintainium provider is an executable plugin that translates an upstream software source into normalized Wintainium release and artifact-candidate information.

Providers discover upstream state. They do not own update decisions, final artifact selection, downloading, verification, installation, or orchestration.

## Boundary

```text
Validated Manifest
    |
    | provider identity + contract version + non-secret settings
    v
Provider Resolution
    |
    v
Provider Request
    |
    v
Provider Plugin
    |
    | upstream network access is permitted here
    v
Provider Result
    |
    v
Normalized Release / Artifact Candidates
    |
    v
Phase 4+ Core lifecycle processing
```

The Phase 2 Manifest Engine remains local and offline. Manifest import and discovery must never invoke providers or contact upstream services.

## Provider Descriptor

The existing plugin descriptor is the provider identity contract. A provider descriptor contains:

- `pluginId`
- `pluginType` = `Provider`
- `contractVersions`
- `capabilities`

Provider IDs use the stable form `Wintainium.provider.<name>` and are independent of display names.

The descriptor describes supported contracts and capabilities. It must not contain arbitrary executable commands or PowerShell expressions.

## Contract Versioning

Provider Contract Version 1 uses positive major-version identifiers such as `"1"`.

A manifest's `source.requiredContractVersion` identifies the contract required by that application source. A provider is compatible only when it explicitly advertises that required major version.

Breaking provider-contract changes require a new major contract version.

## Provider Request

Core supplies a purpose-built request rather than the entire application manifest. The conceptual contract is:

- `OperationId` — Core correlation identifier.
- `ApplicationId` — normalized Wintainium application identity.
- `ProviderId` — resolved provider identity.
- `RequiredContractVersion` — resolved provider contract major version.
- `Settings` — validated, non-secret provider settings.
- `DiscoveryContext` — narrowly scoped discovery intent required by the provider contract.

Providers must not receive arbitrary executable manifest content, installer commands, download destinations, or raw credentials.

## Release Model

A normalized release contains only provider-independent Wintainium concepts:

- `ReleaseId` — opaque upstream/provider release identifier.
- `Version` — upstream version string; Wintainium does not assume a versioning scheme in Phase 3.
- `Channel` — normalized Wintainium release channel classification.
- `PublishedAt` — optional publication timestamp.
- `Artifacts` — zero or more artifact candidates.

Provider-specific release fields remain provider-owned unless a future architecture decision deliberately promotes a field into the Core model.

Channel is the authoritative normalized channel concept. Prerelease semantics must not be represented by contradictory duplicate state.

## Artifact Model

A normalized artifact candidate may contain:

- `Uri` — untrusted artifact location data.
- `FileName` — upstream filename when known.
- `Format` — normalized artifact format when known, such as `exe`, `msi`, or `zip`.
- `Architecture` — normalized architecture when known, such as `x86`, `x64`, `arm64`, `any`, or `unknown`.
- `Size` — optional upstream-reported size.
- `Hashes` — optional upstream-declared cryptographic hash metadata.
- `Signature` — optional upstream-declared signature metadata.

Providers discover artifact candidates but never select the final artifact. Provider-reported hashes and signatures are claims from the source; verification of downloaded bytes belongs to the Download/Verification phase.

Artifact URIs are data, never executable instructions.

## Provider Result

A provider operation returns a structured result containing:

- `OperationId`
- `IsSuccessful`
- `Status`
- `Releases`
- `Errors`
- `Warnings`
- `LogEvents`

`NoReleasesFound` is a successful source interaction with no matching releases and must remain distinct from source or provider failure.

Expected failure categories include:

- `ConfigurationInvalid`
- `AuthenticationFailed`
- `SourceNotFound`
- `SourceUnavailable`
- `UpstreamResponseInvalid`
- `ProviderResultInvalid`
- `ProviderInternalError`

Core resolution failures remain distinct, including:

- `ProviderNotRegistered`
- `ProviderContractIncompatible`
- `ProviderCapabilityUnsupported`

## Capabilities

Capabilities describe provider operations or meaningful provider features, not upstream API implementation details. The minimum Phase 3 provider discovery capabilities are:

- `releaseDiscovery`
- `artifactDiscovery`

Additional capabilities may be added only when they represent a stable Wintainium contract need.

## Artifact Selection Boundary

The provider reports available releases and artifact candidates. Core later determines the appropriate release and artifact using manifest policy, machine capabilities, installer compatibility, trust policy, and other lifecycle rules.

Providers therefore remain replaceable: GitHub, vendor APIs, feeds, and other upstream implementations all target the same normalized Core boundary.

## Network and Security Boundary

Provider operations may communicate with upstream sources. The Manifest Engine may not.

Manifests are declarative data. They must never contain provider commands, arbitrary PowerShell, or secrets. Provider settings may contain non-secret source configuration. Authentication secrets belong to secure machine/user configuration or credential mechanisms outside the manifest.

Providers communicate only with Core and their declared upstream source. Providers do not invoke other plugins or bypass Core policy.

## Logging and Correlation

Provider operations participate in Core correlation by propagating `OperationId` and emitting structured log events through the Core logging model.

Providers must not create a competing logging/correlation contract.

## Provider-Specific Data Isolation

The normalized Core release and artifact models are intentionally small. Provider-specific API fields remain inside the provider implementation. They must not be placed into an unrestricted generic metadata bag that becomes an undocumented second Core schema.

A provider-specific field may enter a normalized Core model only through a deliberate future architecture decision.
