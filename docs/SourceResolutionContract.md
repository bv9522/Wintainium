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

A successful `Source` contains normalized facts only. Provider-specific upstream response objects do not cross the boundary.

The normalized source model may contain:

- `ApplicationId`
- `Name`
- `Publisher`
- `Homepage`
- `CanonicalUri`
- `ProviderId`
- `ProviderContractVersion`
- `ProviderSettings`
- `SourceContext`

`SourceContext` is reserved for narrowly defined source identity required by the selected provider. It is not an unrestricted metadata bag.

## Status semantics

A resolver must distinguish at least:

- `Resolved`
- `SourceInvalid`
- `SourceUnsupported`
- `SourceAmbiguous`
- `SourceUnavailable`
- `AuthenticationRequired`
- `InteractiveResolutionRequired`
- `SourceResponseInvalid`
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

The same module/entry-point restrictions and correlation rules used by Provider Contract v1 apply.

## Architectural ownership

- Core owns URI validation, operation correlation, result validation, capability selection, and lifecycle composition.
- The resolver owns source-specific interpretation.
- The provider's normal release-discovery operation remains responsible for releases and artifact candidates.
- Core's existing update-decision layer remains responsible for release/artifact policy.
- The desktop client supplies the URL and presents the structured result.

## Compatibility

This contract is additive. Provider Contract v1 remains the release/artifact discovery contract. A provider may implement both capabilities without changing its existing release-discovery operation.

The first reference implementation will be GitHub Releases.
