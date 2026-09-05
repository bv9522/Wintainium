# Phase 7E — Orchestration Cancellation Context

## Purpose

Phase 7E defines the Core-owned cancellation context carried by an
orchestration operation. The context preserves the parent operation identifier
and exposes the caller-supplied `CancellationToken` to downstream stage
boundaries.

`New-WintainiumOrchestrationCancellationContext` does not execute work, cancel
a token, mutate operation state, or terminate a process.

## Input

The boundary accepts:

- the current orchestration `OperationState`;
- an optional `CancellationToken`, defaulting to
  `[System.Threading.CancellationToken]::None`.

The operation state must contain a valid GUID `OperationId`.

## Output

A valid context contains:

- `OperationId`, copied from the orchestration operation state;
- `CancellationToken`, preserving the exact caller-supplied token;
- `IsCancellationRequested`, a snapshot of the token's state when the context
  is created.

The token itself remains live. Consumers that execute cancellable work must
observe the token directly rather than relying on the snapshot property.

## Ownership

Orchestration owns propagation of cancellation intent across stage boundaries.
Individual stage engines remain responsible for observing the token according
to their own contracts. Phase 6E remains the owner of installer process
cancellation and process-tree termination.

This context does not introduce automatic retries, stage skipping, state
transitions, or cancellation-specific installation behavior.

## Security and Lifecycle Boundary

Cancellation is control flow, not authorization. A cancellation token does not
establish artifact authenticity, integrity, signature validity, trust, or
installation approval.

The boundary does not execute provider code, download artifacts, verify bytes,
select installers, launch processes, or reconcile installed application state.
