# Public PowerShell Result Contract

Phase 8B defines the result boundary consumed by the PowerShell CLI and the future C#/.NET presentation layer.

## Common shape

A supported public operation returns a structured PowerShell object. It does not return formatted human-readable text as its primary result.

Where applicable, public results expose these stable concepts:

- `OperationId` — a Core-generated correlation identifier for the operation;
- `IsSuccessful` or an operation-specific validity property such as `IsValid`;
- operation-specific result data;
- `Errors` — zero or more structured error objects;
- `Warnings` — zero or more structured warning objects;
- `LogEvents` — structured diagnostic events when the operation owns logging at its boundary.

Consumers must not depend on property ordering, console formatting, or diagnostic message wording for business decisions.

## Error shape

Expected operational failures are represented as structured data rather than requiring callers to parse exception text.

The preferred error shape is:

- `Code` — stable machine-readable category/code;
- `Message` — human-readable explanation;
- optional operation-specific context where already part of the underlying contract.

Public operations should normalize failures into meaningful categories including invalid caller input, invalid application definition, plugin/provider discovery failure, acquisition failure, verification failure, installer failure, cancellation, and unexpected internal failure.

Exact error codes may evolve within the owning contract, but callers should branch on documented codes/categories rather than message text.

## Operation correlation

An operation that performs or coordinates work must expose its `OperationId` in its top-level result. Nested stage or subsystem results may have their own identifiers, but the parent operation identifier remains the correlation key for the public operation.

The public client must not generate or replace Core-owned operation identifiers.

## Presentation boundary

Human-readable presentation and machine-readable serialization belong outside the business rules. The Core returns structured objects; a CLI presentation layer may format those objects for a terminal, while a future GUI may bind directly to the same semantic data.

Presentation mode must never change provider selection, update decisions, download behavior, verification requirements, installer selection, cancellation semantics, or other business rules.

## Current public operations

The current stable public surface consists of:

- `Get-WintainiumManifest`;
- `Test-WintainiumApplicationDefinition`;
- `Get-WintainiumApplicationRelease`.

These operations already return structured results and retain their operation correlation identifiers.

## End-to-end update operation

The eventual public update command must accept stable application-management inputs and return a stable orchestration result. Callers must not be required to construct `StagePlan`, `CancellationContext`, stage bindings, provider requests, download requests, installer requests, or other private contracts.

The Phase 7 lifecycle primitive intentionally requires those internal dependencies. Therefore it is not itself a public CLI contract. A dedicated internal composition boundary must first assemble the real stage executors and dependencies. Only then should a public orchestration command be exposed.

This prevents the CLI or future GUI from becoming coupled to Phase 7's internal orchestration mechanics.

## Pipeline behavior

Public commands may accept pipeline input where that improves normal PowerShell usage and does not obscure the operation boundary. Pipeline support is not required merely for symmetry.

Structured results should remain usable with `Select-Object`, `Where-Object`, `ForEach-Object`, `ConvertTo-Json`, and other normal PowerShell tooling without requiring formatted-output parsing.

## Non-goals

This contract does not introduce scheduling, update-all orchestration, persistence infrastructure, cloud services, telemetry, marketplace behavior, arbitrary shell execution, or a C#/.NET GUI.
