# Phase 12 — Source Resolution Architecture

## Status

The Phase 12 source-resolution architecture and official-download-page reference implementation are established. The official-download-page focused checkpoint is **7/7 green**.

Phase 12B extends Wintainium from applications that already have an authored manifest to applications that can be onboarded from an official software source URL.

The user-facing input is a source URL. The desktop client does not author provider settings, installer settings, release policy, artifact policy, or JSON manifests.

## Product boundary

Wintainium should accept an official software source or release URL when a supported source-resolution capability can reliably understand that source.

Examples of intended source classes include:

- structured release services such as GitHub Releases;
- official vendor APIs or release feeds;
- structured official download pages whose artifact choices can be normalized safely.

Wintainium must not promise that arbitrary interactive websites can be understood automatically. A source that requires authentication, subscription selection, browser interaction, or otherwise cannot be resolved deterministically may return a structured unsupported or interactive-source result.

## Architecture

The onboarding boundary is:

```
User source URL
      |
      v
Source Onboarding
      |
      +-- validate/normalize URI
      |
      +-- resolve a capable source resolver
      |
      +-- resolve source identity
      |
      +-- construct application-definition facts
      |
      v
Existing Core lifecycle
      |
      +-- release discovery
      +-- update decision
      +-- download
      +-- verification
      +-- installer
      +-- reconciliation
```

Source resolution does not perform an update.

The existing lifecycle remains authoritative after onboarding.

## Source-resolution contract

Source resolution consumes a normalized source URI and Core operation correlation data.

A successful resolution returns normalized facts sufficient for the next Core layer to construct an application definition. It may include:

- stable application identity;
- human-readable application name;
- publisher;
- homepage;
- canonical source URI;
- source-family/provider identity;
- provider settings required for subsequent release discovery;
- source-specific release context when explicitly present in the input URI;
- confidence/ambiguity information where the source can be understood but identity is not unique.

It must not return arbitrary provider metadata as a second Core schema.

A source-resolution operation returns exactly one structured result with:

- OperationId;
- IsSuccessful;
- Status;
- Source;
- Errors;
- Warnings;
- LogEvents.

Expected non-success states are structured. In particular, unsupported, ambiguous, unavailable, authentication-required, and interactive-source conditions must not be represented as successful partial application definitions.

## Separation of responsibilities

**Source resolution discovers what the URL represents.**

**Provider release discovery discovers releases and artifact candidates.**

**Core decides release/artifact eligibility and update policy.**

**Download, verification, installation, and reconciliation remain unchanged.**

A source resolver must not select the final artifact for the current machine. Environment-aware artifact selection remains a later Core responsibility.

## Provider relationship

Existing Provider Contract v1 remains valid for release/artifact discovery.

Source resolution is an optional provider capability rather than a mandatory requirement of every existing provider. This preserves existing providers and allows Phase 12B to add source-resolution support without making unrelated providers implement onboarding.

The fixed source-resolution operation is a constrained plugin boundary. Provider-specific implementation remains inside the provider module; Core owns invocation, result validation, correlation, and lifecycle composition.

## Source-family strategy

GitHub Releases is the first reference implementation because its URL structure and release API provide a deterministic vertical slice.

Structured official download pages are a later source family. They should be interpreted through generalized source-resolution machinery rather than by adding one Core implementation per vendor.

Vendor-specific rules, when genuinely required, belong behind the source-resolution boundary and must produce the same normalized result.

Interactive vendor pages are a legitimate unsupported boundary when deterministic resolution is not possible.

## Security and trust

A URL does not by itself establish that a source is trustworthy. Source resolution must preserve the supplied URI and canonical identity, while later provider and verification layers retain their existing trust responsibilities.

Source-resolution implementations must not execute downloaded content, execute page-provided commands, or accept manifest-controlled executable instructions.

## Phase 12B roadmap

- **12.1 — Source Onboarding Contract:** define the normalized source input/result boundary.
- **12.2 — Source Resolution Architecture:** add optional provider source-resolution capability without breaking Provider Contract v1.
- **12.3 — GitHub Source Resolution:** resolve repository/release URLs into normalized source facts.
- **12.4 — Normalized Application Model:** construct an application definition from resolved facts without moving lifecycle policy into onboarding.
- **12.5 — Official Download Page Resolution:** add generalized structured-page resolution and fixtures.
- **12.6 — Environment Model:** establish authoritative Windows/machine facts.
- **12.7 — Artifact Selection Integration:** connect environment facts to existing Core eligibility/selection.
- **12.8 — Persistence:** persist onboarded application definitions under one authoritative ownership model.
- **12.9 — Desktop Integration:** make Add Software pass only the source URL to Core and present structured results.
- **12.10 — Real-World Source Validation:** validate GitHub, 7-Zip, VLC, WinRAR, and similar sources.
- **12.11 — Unsupported/Interactive Source Handling:** validate deterministic failure semantics.
- **12.12 — Integration, Regression, Audit & Lock.**

## Non-goals

Phase 12B does not:

- move provider logic into the GUI;
- require users to author JSON;
- scrape arbitrary websites indiscriminately;
- create a vendor-specific branch in Core for every software publisher;
- replace the existing manifest engine;
- replace Provider Contract v1 release/artifact discovery;
- select artifacts using GUI logic;
- make an interactive vendor website magically automatable.


## Official download-page reference implementation

The `Wintainium.provider.official-download-page` provider implements the constrained structured-page source family. It accepts absolute HTTP/HTTPS pages, retrieves HTML as untrusted data, extracts supported identity metadata and canonical URI information, and returns normalized source facts. It does not execute page scripts, select final artifacts, or perform an update.

Supported identity sources are evaluated in deterministic order: `application-name`, `og:site_name`, `og:title`, the first `h1`, then `title`. Metadata and canonical-link attributes may appear in arbitrary attribute order. Non-HTML responses, empty documents, unsupported schemes, and pages without usable identity produce structured failures.

The provider uses a bounded redirect count and request timeout. Dynamic, authenticated, subscription-gated, anti-bot, or otherwise non-deterministic pages remain outside this resolver's promise and are handled by later unsupported/interactive-source work.


## Phase 12.7 — Artifact Selection Integration

The Core-owned environment snapshot is now integrated into the artifact-selection path. Update decisions create and pass the environment snapshot through target resolution, artifact selection, and artifact eligibility. The existing manifest artifact policy and deterministic ranking rules remain authoritative.

The legacy machine-architecture parameter remains as a compatibility seam for existing callers, but downstream selection uses the environment snapshot's MachineArchitecture when an environment snapshot is supplied. This prevents artifact selection from depending on scattered process/global architecture reads while preserving the established lower-level contracts.

Focused validation:
- Update decision environment precedence: **6/6 green**
- Artifact selection environment precedence: **9/9 green**
- Artifact eligibility environment precedence: **11/11 green**


## Phase 12.8 — Persistence

Application-definition persistence is now established under the existing manifest collection boundary. `Set-WintainiumApplicationDefinition` accepts a normalized application definition, serializes it to a temporary file, validates the serialized document against the authoritative application-manifest schema, and only then derives the destination from the validated application identity. The final file convention is `<ManifestRoot>/<ApplicationId>.wintainium.json`, with replacement semantics by application identity and atomic file replacement.

This does not create a second state authority. Installed application observations remain owned by the existing `installed-state.json` boundary, while desktop settings and notes remain session-scoped until a separate durable desktop-configuration contract is defined. Source onboarding therefore produces a durable application definition without mutating installed state.

Focused validation: **6/6 green**.
