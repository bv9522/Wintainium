# Source Resolution Contract

## Purpose

The Source Resolution Contract defines the Core/plugin boundary used when a user supplies an official software source URL instead of an authored application manifest.

The contract is intentionally narrower than release discovery. It answers:

> What does this source URL represent, and what normalized source facts can Wintainium use to construct an application definition?

It does not answer whether an update is required or which artifact should ultimately be installed.

## Input

Core supplies:

- `OperationId` — Core-generated correlation identifier.
- `SourceUri` — the user-supplied absolute HTTP/HTTPS URI.
- `ResolutionContext` — optional Core-owned context needed to constrain resolution without embedding GUI policy.

The resolver must not require the GUI to provide provider-specific settings.

## Result

The resolver returns exactly one structured result:

| Property | Meaning |
|---|---|
| `OperationId` | Must exactly match the Core request. |
| `IsSuccessful` | Whether a complete source resolution was established. |
| `Status` | Machine-readable terminal status. |
| `Source` | Normalized source facts when resolution succeeds. |
| `Errors` | Structured errors. |
| `Warnings` | Structured warnings. |
| `LogEvents` | Correlated diagnostic events. |

A successful `Source` contains normalized facts only. Provider-specific upstream response objects do not cross the boundary. Core verifies that `Source.ProviderId` matches the selected provider descriptor, that `Source.ProviderContractVersion` is advertised by that descriptor, and that `CanonicalUri` is an absolute HTTP/HTTPS URI before accepting the result. A failed result must not contain a partial `Source` object.

The normalized source model may contain:

- `ApplicationId` — provider-assigned stable Wintainium identifier for the application record. It must derive from stable upstream/source identity rather than the display name. Cross-provider deduplication is not implied.
- `Name` — primary display name.
- optional `Aliases` — alternate application/display names established by the resolver. These are not package identifiers, executable paths, or publisher identities.
- `Publisher`
- `Homepage`
- `CanonicalUri` — resolver-established canonical source identity URI.
- `ProviderId`
- `ProviderContractVersion`
- `ProviderSettings` — provider-owned upstream locator/configuration.
- `SourceContext` — optional provider-established facts about the submitted source, distinct from the upstream locator.

`SourceContext` is persisted as `source.context`. Providers may represent this JSON object as either an `IDictionary` or a `PSCustomObject`; Core normalizes both forms into a dictionary before persistence. Its contents must be JSON-compatible, with Core enforcing bounded depth, item count, string length, and serialized size. Credential-like keys remain prohibited by manifest semantic validation. Core preserves the structure without interpreting provider-specific fields; providers own their meaning. Context is refreshed from the newly resolved source during re-onboarding rather than blindly carrying forward potentially stale provider facts.

Identity aliases have separate provenance. `aliases` contains provider-suggested alternate display names. `userConfirmedAliases` contains aliases explicitly confirmed by the user and is preserved by Core during re-onboarding. Existing manifests predating `userConfirmedAliases` do not record alias provenance; their existing `aliases` are conservatively migrated into the confirmed collection so they are not silently lost. Duplicate aliases are normalized case-insensitively, and the primary display name is never stored as an alias. An explicitly present but empty `userConfirmedAliases` collection is preserved as empty so provider suggestions are not later mistaken for legacy confirmed aliases. If an existing manifest cannot be read during re-onboarding, Core stops rather than overwrite it and risk losing user-owned identity or reconciliation data.

`SourceContext` is reserved for narrowly defined source identity required by the selected provider. It is not an unrestricted metadata bag.

Core separately preserves the exact user-supplied URL as `Source.submittedUri`; this is not resolver-authored data. The resolver's `CanonicalUri` is persisted as `Source.canonicalUri`. Provider-specific upstream locators remain in `Source.ProviderSettings`. These fields must not be conflated: a release page, redirect destination, canonical product page, and upstream repository identity can be different values.

## Status semantics

A resolver must distinguish at least:

- `Resolved`
- `SourceInvalid`
- `SourceUnsupported`
- `SourceAmbiguous`
- `SourceUnavailable`
- `AuthenticationRequired`
- `InteractiveResolutionRequired` — the source requires an interactive browser or authentication step that the provider's deterministic HTTP retrieval path cannot complete.
- `SourceResponseInvalid`
- `SourceResolutionResultInvalid` — Core rejected a resolver result that violated the normalized source contract.
- `SourceResolverInternalError`

A non-success result must not contain a partially constructed application definition that Core could accidentally treat as authoritative.

## Capability advertisement

Source resolution is an optional provider capability:

```json
"capabilities": {
  "releaseDiscovery": true,
  "artifactDiscovery": true,
  "sourceResolution": true
}
```

Existing providers remain valid without `sourceResolution`.

A provider advertising `sourceResolution=true` must expose the fixed source-resolution operation defined by this contract.

## Fixed operation boundary

Core invokes a constrained operation equivalent to:

```powershell
Invoke-WintainiumProviderSourceResolution -Request <SourceResolutionRequest>
```

The operation name is fixed. Providers do not receive arbitrary command names from Core or the user.

The same module/entry-point restrictions and correlation rules used by Provider Contract v1 apply. Core binds the invocation to the exact resolved provider module and validates that the returned provider identity and contract version match the selected descriptor.

## Resolver competition policy

Core invokes every registered provider that advertises `sourceResolution`; descriptor order is deterministic for repeatable diagnostics, not a provider-precedence rule. Core does not select a provider by registration order, confidence score, or vendor-specific priority.

- Exactly one successful resolver: accept that normalized result.
- More than one successful resolver: reject the operation as `SourceAmbiguous`; do not silently choose between competing identities.
- Exactly one successful resolver plus any other resolver reporting `SourceAmbiguous`: also reject as `SourceAmbiguous`. An explicit provider ambiguity is positive evidence that the submitted source may map to multiple identities; Core has no provider-priority or confidence contract that would justify overriding it.
- No successful resolver: fail without constructing or persisting an application definition. Preserve the provider-specific outcomes and select the operation status using this deterministic precedence: `SourceAmbiguous`, `SourceUnavailable`, `AuthenticationRequired`, `InteractiveResolutionRequired`, `SourceResponseInvalid`, `SourceResolutionResultInvalid`, `SourceResolverInternalError`, then `SourceUnsupported` when none of the preceding statuses was reported. This is terminal-status selection only; it is not provider precedence and never selects a source identity.
- If one resolver succeeds while others return ordinary `SourceUnsupported` or `SourceInvalid` declines, accept the sole successful result. Those expected declines do not veto a provider that established a complete identity.
- If one resolver succeeds while another reports a non-decline failure (for example, `SourceUnavailable`, `AuthenticationRequired`, `InteractiveResolutionRequired`, `SourceResponseInvalid`, or an internal/contract failure), retain the successful result but surface the competing failure as a warning. The failure must not be silently discarded.

Core emits one `SourceResolutionDecisionEvaluated` log event for the aggregate decision. Its structured context records the outcome, provider-attempt counts, successful provider IDs, the selected provider ID only when Core actually accepts a unique result, and ambiguity reason/provider IDs when applicable. `Ambiguous` can mean multiple successful providers or an explicit `SourceAmbiguous` response from another provider. It contains no submitted URL or query string. Individual provider events and diagnostics remain the evidence for each attempt.

## Architectural ownership

- Core owns URI validation, operation correlation, result validation, capability selection, and lifecycle composition.
- The resolver owns source-specific interpretation.
- The provider's normal release-discovery operation remains responsible for releases and artifact candidates.
- Core's existing update-decision layer remains responsible for release/artifact policy.
- The desktop client supplies the URL and presents the structured result.

## Compatibility

This contract is additive. Provider Contract v1 remains the release/artifact discovery contract. A provider may implement both capabilities without changing its existing release-discovery operation.

The first reference implementation will be GitHub Releases.
