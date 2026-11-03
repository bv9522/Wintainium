# Stage 2A — Normalized Contract Design

**Status:** Proposed for review; no runtime contract has been changed by this document.  
**Scope:** Define the shared identity, discovery-evidence, release/artifact, and verification result models that later work can implement incrementally.  
**Base:** `phase-14-gui-productization`  
**Design branch:** `stage-2a-contract-design`

## 1. Objective and non-goals

Stage 2A establishes a common vocabulary and explicit information flow across existing Wintainium boundaries. It is not a parser rewrite, provider rewrite, installer rewrite, diagnostics rewrite, or manifest redesign.

The current architecture remains the foundation:

**Manifest describes → Provider discovers → Core decides → Download obtains → Verification establishes integrity/trust → Installer applies → Orchestration coordinates → UX presents.**

This proposal is additive at the design level. Existing Provider Contract v1, plugin descriptors, manifests, installer plugins, reconciliation plugins, and public PowerShell commands remain in place until a later, separately reviewed migration step.

Non-goals for 2A:
- changing source-resolution algorithms or provider dispatch;
- changing release parsing, HTML extraction, sidecar discovery, or GitHub API calls;
- changing artifact ranking, installer selection, or architecture policy;
- relaxing mandatory verification or accepting weaker evidence implicitly;
- adding application-specific branches to Core or generic providers;
- changing desktop diagnostics presentation or the PowerShell host allowlist;
- deleting or replacing existing contracts, helpers, providers, or plugins.

## 2. Design principles

1. **Normalize meaning, preserve provenance.** Core-facing fields use provider-independent concepts, while every externally asserted claim retains enough provenance to explain where it came from and what it describes.
2. **Identity is not a URL.** A submitted URL, canonical source URL, provider ID, upstream product ID, and Wintainium ApplicationId are distinct values.
3. **Discovery is not selection.** Providers report observations and candidates. Core applies release, architecture, format, compatibility, and trust policy.
4. **A claim is not a fact.** A publisher-declared digest or signature is an assertion. Verification records the evaluation of that assertion against downloaded bytes or a cryptographic trust policy.
5. **Integrity is not publisher authenticity.** A matching SHA-256 digest establishes byte equality with the referenced claim; by itself it does not establish who published the claim or artifact.
6. **Evidence association must be explicit.** A checksum must identify the artifact it is claimed to describe. An unassociated digest must not silently become an artifact hash.
7. **No generic metadata dumping ground.** Do not introduce an unrestricted provider metadata bag. New normalized fields require explicit contract decisions and schema validation.
8. **Preserve resolution layers.** A standard strategy, conditional strategy, and specialized strategy can coexist. New evidence fields must make those layers explainable, not collapse them into a single opaque outcome.
9. **Core remains authoritative.** Plugins discover. Core validates, correlates, selects, and applies policy. The desktop presents structured results only.

## 3. Proposed normalized identity model

### 3.1 Application identity

The managed application identity remains the stable Wintainium `ApplicationId`. It must not be recalculated from a mutable display name or from whichever source URL happened to be submitted.

Conceptual shape:

| Field | Meaning | Owner |
|---|---|---|
| `ApplicationId` | Stable Wintainium-managed identity | Core / manifest |
| `DisplayName` | Human-readable application name | Manifest / Core |
| `Publisher` | Publisher label when known | Manifest / discovery observation |
| `Aliases` | Known alternate product names | Manifest / normalized discovery |
| `HomepageUri` | Canonical product homepage when established | Manifest / normalized discovery |
| `Source` | Provider reference and validated settings | Manifest |
| `UpstreamIdentity` | Optional provider-neutral external identity assertion | Discovery evidence |

`UpstreamIdentity` should be a small typed object, not an arbitrary dictionary. Initial candidates are `Namespace`, `Value`, and optional `AuthorityUri`. It is descriptive/corroborating evidence; it does not replace `ApplicationId` and must not silently merge two managed applications.

### 3.2 Source identity

Keep these concepts separate:
- `SubmittedUri`: the user-provided onboarding input;
- `CanonicalSourceUri`: the provider-normalized source location, when known;
- `ProviderId`: the selected Wintainium provider plugin;
- `ApplicationId`: the stable managed application identity;
- `UpstreamIdentity`: an optional source-system product/repository/package identifier.

A canonical URI can improve deduplication and source continuity, but URL equivalence alone is insufficient proof that two products are the same application. Identity conflicts or multiple plausible identities remain structured ambiguous outcomes requiring Core policy or user resolution.

## 4. Proposed discovery evidence model

### 4.1 Evidence record

Introduce a typed, provider-independent evidence record for externally asserted metadata.

| Field | Meaning |
|---|---|
| `EvidenceId` | Stable identifier within the operation/result |
| `EvidenceType` | For example `HashClaim`, `SignatureClaim`, `ProductIdentityClaim`, `ReleaseIdentityClaim` |
| `SourceKind` | Controlled Wintainium vocabulary describing where the claim was observed |
| `SourceUri` | URI of the page, API resource, sidecar, or metadata endpoint |
| `ObservedAt` | UTC observation timestamp, when available |
| `Association` | Typed association to a release/artifact, including method and matched subject |
| `Claim` | Typed payload specific to EvidenceType |

For hash evidence, `Claim` is a typed hash claim:
- `Algorithm` (normalized token, e.g. `SHA256`, `MD5`);
- `Value` (normalized digest text);
- optional `SubjectFileName`;
- optional `SubjectUri`.

The association should record how the evidence was linked to the artifact, for example `ExactFileName`, `ArtifactUri`, `SidecarFileName`, or `SingleUnambiguousClaim`. It should also retain the matched filename/URI where applicable. The method describes the association mechanism; it is not a trust rating.

### 4.2 Source-kind vocabulary

Initial controlled values should cover the existing and foreseeable reusable sources:
- `ReleaseMetadata` (release API/feed response);
- `OfficialDownloadPage` (publisher page content);
- `ChecksumSidecar` (adjacent checksum file);
- `ArtifactEndpoint` (metadata obtained from an artifact endpoint/API);
- `PublisherSignatureMetadata` (signature claim or signing metadata);
- `UserSupplied` (explicit user-provided evidence, if supported later).

This vocabulary is deliberately source-neutral. A platform-specific implementation detail such as a GitHub asset digest is represented by a general source kind plus its source URI and association, not by a GitHub-only Core property.

### 4.3 Evidence validation rules

Core must validate:
- required fields and supported evidence type;
- digest algorithm and syntax;
- URI shape and permitted schemes under existing network policy;
- operation correlation;
- association completeness and consistency;
- duplicate/conflicting claims without silently choosing one.

A hash claim with no unambiguous artifact association remains an observation, not an eligible verification input. Multiple conflicting claims remain visible and produce a structured conflict/ambiguity outcome. Do not silently select the first claim.

Provider-specific raw response data remains inside the provider. The normalized evidence record contains only the minimum facts needed by Core to reason and explain.

## 5. Proposed release and artifact model

The current normalized release/artifact model remains recognizable. The proposal formalizes identifiers and evidence references without moving selection into providers.

### Release

- `ReleaseId`: opaque provider/upstream release identifier;
- `Version`: original upstream version string;
- `Channel`: normalized Wintainium channel;
- `PublishedAt`: optional timestamp;
- `Artifacts`: candidate artifacts;
- `Evidence`: optional release-level identity/publication claims.

### Artifact candidate

- `ArtifactId`: stable within its containing release/result;
- `Uri`: untrusted artifact location;
- `SourcePageUri`: optional page from which the link was discovered;
- `FileName`: upstream filename, when known;
- `Format`: normalized format;
- `Architecture`: normalized architecture or `Unknown`;
- `Size`: optional reported size;
- `Evidence`: typed evidence records associated with this artifact;
- `SignatureClaims`: represented through typed evidence, not interpreted as verified signatures.

A transitional implementation may continue exposing the existing `Hashes` and `Signature` properties while a new `Evidence` collection is introduced. The migration must define precedence and conflict handling; it must not create two independently authoritative sources of hash truth.

### Selection boundary

Providers return candidates and evidence. Core continues to select the release and artifact according to manifest policy, machine capabilities, installer compatibility, and trust/verification policy. Artifact identity and evidence association must be established before selection consumes a claim.

## 6. Proposed verification request and result

### 6.1 Verification request

The verifier receives:
- `OperationId`;
- the selected normalized artifact, including its associated evidence;
- the completed download result/path;
- the effective Core verification policy;
- any explicit per-operation user authorization already required by existing reduced-assurance behavior.

The verifier does not receive arbitrary provider response objects or an unrestricted metadata bag.

### 6.2 Verification result

Replace the overloaded interpretation of a single `VerificationLevel` with separate, explicit dimensions.

| Field | Meaning |
|---|---|
| `OperationId` | Correlation identifier |
| `Status` | Overall structured operation outcome |
| `IntegrityStatus` | `Verified`, `Failed`, `NotEvaluated`, or `Unavailable` |
| `PublisherAuthenticityStatus` | `Verified`, `Failed`, `NotEvaluated`, or `Unavailable` |
| `TransportStatus` | Relevant transport observations; not a substitute for artifact integrity |
| `Evaluations` | One result per evidence claim actually evaluated |
| `DownloadedArtifact` | File name, length, and safe display metadata |
| `UserAuthorization` | Explicit authorization record when a reduced-assurance path is used |
| `FailureKind` / `Errors` | Machine-readable failure and diagnostics |

Each hash evaluation should identify:
- `EvidenceId`;
- `Algorithm`;
- `ExpectedDigest`;
- `ActualDigest`;
- `Match`;
- the source and association summary from the originating evidence.

This preserves the exact reason a SHA-256 comparison passed or failed. It also allows diagnostics to explain whether the claim came from page HTML, a sidecar, an API/endpoint, or another supported source.

### 6.3 Security semantics

- SHA-256 match means the downloaded bytes match the associated SHA-256 claim.
- It does not, by itself, prove that the claim was published by the legitimate publisher.
- Publisher authenticity requires a separate evaluated trust mechanism, such as a valid Authenticode signature under an explicit publisher policy.
- Transport security describes the retrieval channel and must not be promoted into artifact authenticity.
- MD5 remains reduced assurance and requires the existing explicit user authorization. It must never be silently treated as equivalent to SHA-256.
- No new evidence source can bypass Core's verification requirement or convert an untrusted claim into a trusted one merely by being discovered.

## 7. Boundary ownership and information flow

| Boundary | Receives | May produce | Must not do |
|---|---|---|---|
| Manifest → Core | Stable ApplicationId, provider/installer references, user policy | Validated intent and policy | Carry executable behavior, secrets, or observed machine state |
| Source resolver → Core | Submitted URI and constrained resolution request | Normalized application identity, source identity, typed identity evidence | Persist a manifest or make update decisions |
| Core → release provider | Operation correlation, ApplicationId, provider identity/settings, constrained discovery context | — | Pass raw secrets, installer commands, or unrelated manifest content |
| Release provider → Core | — | Normalized releases, artifact candidates, typed evidence, structured warnings/errors | Select final release/artifact, download, verify, install, or decide update |
| Core selection → Download | Selected release/artifact and policy decision | Download request/result | Infer trust from URL or filename |
| Download → Verification | Completed download and selected artifact evidence | Download metadata | Claim verification merely because download succeeded |
| Verification → Core | Selected artifact, evidence, downloaded bytes/path, verification policy | Per-claim evaluations and separate integrity/authenticity/transport outcomes | Drop evidence provenance or conflate integrity with publisher identity |
| Core → Installer | Verified artifact and selected installer request | Structured install result | Reinterpret verification or weaken Core policy |
| Core → Desktop | Public structured results and diagnostics | Presentation | Expose private provider objects or duplicate policy |

## 8. Contract versioning and migration

1. **Do not mutate Provider Contract v1 semantics in place.** Existing plugins must continue to work while the new model is introduced.
2. Treat provenance-bearing evidence as a breaking provider boundary change unless a strict additive compatibility analysis proves otherwise. The default proposal is a Provider Contract v2 for the normalized evidence-bearing result.
3. Define the verification request/result version independently if that boundary is separately versioned today; do not assume provider and verifier contracts must share a version number.
4. Core owns adapters from v1 provider results to the internal normalized model. Legacy `Hashes` are adapted into evidence records with explicitly limited provenance; missing provenance must remain marked unknown rather than fabricated.
5. During transition, the v1 and v2 providers may coexist. Capability/version resolution must be deterministic and explicit.
6. Add contract fixtures and validation tests before migrating either production provider.
7. Migrate one provider at a time, preserving all current release/artifact behavior and all existing resolution layers.
8. Remove legacy compatibility only after all supported plugins, manifests, and tests have migrated and a separate deprecation decision is accepted.

## 9. Audit constraints to carry forward (not implementation scope here)

These findings are guardrails for later work, not permission to fix those areas during 2A:

- **3.4 — provider specialization:** reusable platform-specific behavior may live in a shared provider capability, but product-specific identity exceptions must not spread through generic Core/provider logic.
- **5.2 — evidence provenance:** the current verification boundary reduces hash claims to algorithm/value and loses the source/association needed to diagnose a mismatch. The proposed evidence model must preserve this chain end to end.
- **6.2 — diagnostics visibility:** structured evidence can exist internally yet be absent from the desktop's selected diagnostic fields. The contract must make provenance available in structured results; the later diagnostics workstream decides how to present it safely.
- **8.1 — boundary alignment:** the C# adapter/host allowlist and Core public surface must remain aligned. This is a separate integration correction; 2A must not turn internal contract types into new public desktop commands.

The exact audit finding labels above are retained as traceability references. Their implementation is deferred to their scheduled roadmap workstreams.

## 10. Known contract drift to reconcile before implementation

The current repository documentation/schema is not perfectly aligned. Before implementing any new contract, resolve these contradictions explicitly rather than choosing whichever file is easiest to edit:

- `schemas/application-manifest.schema.json` allows `x64`, `x86`, and `neutral`, while `docs/ManifestAuthoring.md` and the onboarding contract describe `arm64` support.
- `ARCHITECTURE.md` describes the normalized artifact formats as `exe`, `msi`, and `zip`, while the manifest schema and authoring/onboarding documentation also include `msix`.
- Provider Contract v1 describes hashes/signatures as source claims, but the current verification implementation primarily consumes `Algorithm` and `Value`; its legacy MD5 exception additionally inspects `Source`. The provenance contract is therefore inconsistent across layers.
- The verification result currently labels a matching SHA-256 claim `VerificationLevel='Strong'`, even though that establishes digest equality, not publisher authenticity.

These are design reconciliation items. This document does not change the schema or runtime behavior.

## 11. Proposed acceptance criteria for 2A

2A is ready for implementation planning when Brian approves:

- the distinction between managed identity, submitted/canonical source URI, and upstream identity;
- the typed evidence model and its association rules;
- the artifact/release model and Core-owned selection boundary;
- the split between integrity, publisher authenticity, and transport outcomes;
- the contract versioning and v1 compatibility strategy;
- the deferred handling of audit findings 3.4, 5.2, 6.2, and 8.1.

No parser, provider, verifier, schema, diagnostics, desktop, or installer code should change as part of this design review.
