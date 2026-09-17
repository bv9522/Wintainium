# Wintainium Phase 9F — Failure, Cancellation, and Boundary Hardening

## Scope

Phase 9F hardens the complete internal update lifecycle without changing the locked Phase 1–8 architecture.

## OperationId boundary decision

The orchestration request creates the single lifecycle-owned `OperationId`. The application lifecycle explicitly passes that identifier into the download and installer request helpers.

`New-WintainiumDownloadRequest` and `New-WintainiumInstallerRequest` retain their standalone behavior: when no identifier is supplied they create a fresh valid identifier. When the lifecycle supplies an identifier, they validate and preserve it.

This preserves backward-compatible standalone helper usage while preventing helper-created identifiers from replacing the orchestration-owned lifecycle identity.

## Failure propagation

The lifecycle treats each stage's structured result as authoritative. A failed stage stops downstream stage execution through the existing orchestration boundary; exception-message parsing is not used to determine failure.

The verification gate remains mandatory before installation. Authoritative state persistence is a separate Core boundary after successful reconciliation evidence and never occurs for unsuccessful reconciliation or unknown evidence.

## Cancellation

Cancellation remains owned by the orchestration lifecycle. The same cancellation token is passed into cancellable download and installation operations, while the orchestration stage boundary handles cancellation before and between stages. Cancellation does not create a separate installed-state authority and must not cause authoritative state persistence.

## Regression expectations

Phase 9F coverage must establish:

- provider failure blocks downstream lifecycle stages;
- download failure blocks verification and installation;
- verification failure blocks installation;
- installer failure blocks reconciliation;
- reconciliation failure blocks authoritative persistence;
- cancellation stops lifecycle progression without inventing installed state;
- lifecycle OperationId is preserved through download and installer request creation;
- invalid explicit OperationIds are rejected at those request boundaries;
- structured failures remain available without parsing exception text.

## Exit condition

Phase 9F is complete only after the focused boundary/failure regression is green and the final Phase 1–9 regression is subsequently run under Phase 9G.
