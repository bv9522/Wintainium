# Public PowerShell Result Contract

Phase 8F completed the result-boundary audit established in Phase 8B. Phase 9 supplied the internal verification, post-install reconciliation, and authoritative managed-state lifecycle that now underpin the public update operation.

## Common shape

A supported public operation returns a structured PowerShell object. It does not return formatted human-readable text as its primary result.

Where applicable, public results expose these stable concepts:

- `OperationId` — a Core-generated correlation identifier for the operation;
- `IsSuccessful` or an operation-specific validity property such as `IsValid`;
- `Status` — a stable operation status when the operation has a meaningful status vocabulary;
- operation-specific result data;
- `Errors` — zero or more structured error objects;
- `Warnings` — zero or more structured warning objects;
- `LogEvents` — structured diagnostic events when the operation owns logging at its boundary.

Collection-valued result properties are returned as arrays, including when empty. The audited public implementations preserve those collection properties as actual arrays rather than allowing PowerShell's empty-pipeline behavior to collapse them to `$null`. Consumers must not depend on property ordering, console formatting, or diagnostic message wording for business decisions.

## Supported command contracts

The current public surface has four supported operations. Their top-level result properties are intentionally explicit so a CLI, script, or future GUI can bind to the same semantic data.

| Command | Correlation | Success/validity | Status | Operation data | Diagnostics |
| --- | --- | --- | --- | --- | --- |
| `Get-WintainiumManifest` | `OperationId` | `IsSuccessful` | — | `Candidates`, `ManifestPaths`, `Manifests` | `Errors`, `Warnings`, `LogEvents` |
| `Test-WintainiumApplicationDefinition` | `OperationId` | `IsValid` | — | `Manifest`, `ProviderPlugin`, `InstallerPlugin`, `ReconciliationPlugin` | `Errors`, `Warnings`, `LogEvents` |
| `Get-WintainiumApplicationRelease` | `OperationId` | `IsSuccessful` | `Status` | `Manifest`, `ProviderPlugin`, `Releases` | `Errors`, `Warnings`, `LogEvents` |
| `Invoke-WintainiumApplicationUpdate` | `OperationId` | `IsSuccessful` | `Status` | `ApplicationId`, `Stages` | `Errors`, `Warnings`, `LogEvents`, `Error` |

A consumer should branch on the documented success/validity property and, where provided, `Status`. It should inspect structured error codes for failure handling rather than parse `Message` text.

## Error shape

Expected operational failures are represented as structured data rather than requiring callers to parse exception text.

The preferred error shape is:

- `Code` — stable machine-readable category/code;
- `Message` — human-readable explanation;
- optional operation-specific context where already part of the underlying contract.

The stable error categories recognized by the public boundary are:

| Category | Meaning | Examples of codes |
| --- | --- | --- |
| Caller input | The requested operation cannot begin because a public input is invalid or unusable | `ManifestCollectionNotFound`, `ManifestCollectionPathInvalid` |
| Application definition | The manifest cannot be used as an application definition | `ManifestValidationFailed`, schema/definition validation codes |
| Plugin capability | A required provider, installer, or reconciliation capability cannot be resolved or is incompatible | plugin resolution/compatibility codes |
| Provider/discovery | Upstream release discovery failed after the application definition was accepted | provider-defined discovery codes |
| Acquisition | A release artifact could not be obtained | download failure codes |
| Verification | An obtained artifact could not establish the required integrity result | verification failure codes |
| Installer | Installation could not be selected or applied | installer failure codes |
| Reconciliation | Post-install observation could not establish a valid reconciliation result | reconciliation failure codes |
| Cancellation | Work stopped because cancellation was requested | cancellation codes |
| Internal | An unexpected engine failure escaped normal operation handling | unexpected internal failure codes |

These categories describe the semantic failure boundary; individual owning operations remain responsible for their exact documented codes. Callers should branch on documented codes/categories rather than message text.

## Operation correlation

An operation that performs or coordinates work must expose its `OperationId` in its top-level result. Nested stage or subsystem results may have their own identifiers, but the parent operation identifier remains the correlation key for the public operation.

The public client must not generate or replace Core-owned operation identifiers. When one public command delegates to another Core operation, the outer operation boundary should preserve the identifier when that operation is intentionally the same logical operation.

The Phase 9 internal lifecycle preserves one orchestration-owned OperationId through manifest validation, discovery, decision, download, verification, installer execution, reconciliation, and authoritative-state handling.

## Presentation boundary

Human-readable presentation and machine-readable serialization belong outside the business rules. The Core returns structured objects; a CLI presentation layer may format those objects for a terminal, while a future GUI may bind directly to the same semantic data.

Presentation mode must never change provider selection, update decisions, download behavior, verification requirements, installer selection, cancellation semantics, reconciliation semantics, or other business rules.

## End-to-end update operation

`Invoke-WintainiumApplicationUpdate` accepts stable application-management inputs and returns the Phase 10B public result projection. Callers are not required to construct `StagePlan`, `CancellationContext`, stage bindings, provider requests, download requests, installer requests, reconciliation requests, or other private contracts.

Phase 9 provides the internal composition beneath this boundary: verification is Core-owned and mandatory before installation, reconciliation is an application-scoped evidence boundary, and authoritative installed-state persistence remains Core-owned. Phase 10B deliberately projects that lifecycle into a smaller public shape so internal stage wiring can evolve without becoming public API.

The managed installed-state source remains intentionally narrow: it represents Wintainium-managed state, not Windows-wide inventory. A missing record is `Unknown`, not `NotInstalled`, and authoritative state is never manufactured merely to make an update appear available.

## Pipeline compatibility

Public commands may accept pipeline input where that improves normal PowerShell usage and does not obscure the operation boundary. Pipeline support is not required merely for symmetry.

Structured results should remain usable with `Select-Object`, `Where-Object`, `ForEach-Object`, `ConvertTo-Json`, and other normal PowerShell tooling without requiring formatted-output parsing.

## Help and examples

Public commands use comment-based help as the authoritative local CLI guidance for their currently implemented behavior. Each supported command documents its purpose, public parameters, structured output, and at least one copy/paste-oriented example.

Examples demonstrate public inputs only. The update command's result is documented separately in `docs/PublicApplicationUpdateResult.md`; examples do not expose private orchestration dependencies.

## Non-goals

This contract does not introduce scheduling, update-all orchestration, cloud services, telemetry, marketplace behavior, arbitrary shell execution, or a C#/.NET GUI. The explicitly defined managed-state persistence boundary is part of the internal engine contract but is not a general-purpose public configuration or inventory API.
