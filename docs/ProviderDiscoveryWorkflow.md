# Provider Discovery Workflow

## Phase 3E.2

`Get-WintainiumApplicationRelease` is the public Core workflow for provider-backed release discovery.

The workflow is intentionally ordered:

1. Load and validate the local application manifest.
2. Resolve the declared provider and installer plugins through the existing registry and contract rules.
3. Stop without provider execution when application-definition validation fails.
4. Build a purpose-built `ProviderRequest` containing only Core correlation data, application/provider identity, validated provider settings, and narrowly scoped discovery context.
5. Invoke the resolved provider through the fixed `Invoke-WintainiumProvider` operation boundary.
6. Validate the provider result through the existing Core operation contract.
7. Return normalized releases and artifact candidates to the caller.

The workflow does not select a final release or artifact, download anything, verify downloaded bytes, or install software. Those responsibilities belong to later phases.

## Stable result shape

The command returns:

- `OperationId`
- `IsSuccessful`
- `Status`
- `Manifest`
- `ProviderPlugin`
- `Releases`
- `Errors`
- `Warnings`
- `LogEvents`

Validation and provider events use the same Core operation identifier, preserving one correlation chain from manifest validation through provider discovery.

## Source neutrality

The workflow is intentionally provider-neutral. GitHub Releases is the first real provider, but Core does not contain GitHub-specific branching. Future providers for official vendor websites, vendor APIs, feeds, CDNs, local repositories, or other authoritative sources enter through the same provider contract and operation boundary.
