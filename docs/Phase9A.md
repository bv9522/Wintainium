# Phase 9A — Lifecycle Contract and Evidence Model

## Purpose

Define the contracts that connect the existing lifecycle engines without collapsing their responsibilities.

## Required distinctions

| Concept | Meaning |
|---|---|
| Downloaded | An artifact was obtained at a local path by the download engine. |
| Verified | The artifact satisfied the applicable Wintainium verification policy and evidence. |
| Installed | Installation execution completed according to the installer contract. This alone is not authoritative installed state. |
| Reconciled | A dedicated reconciliation provider supplied authoritative evidence about the application's resulting managed state. |
| Authoritative managed state | The normalized state persisted by Core from valid reconciliation evidence. |

## Trust boundary

Installation is permitted only after verification has produced an acceptable result for the exact downloaded artifact. A successful download must never implicitly satisfy verification.

## State boundary

The selected release is an intended target, not evidence that the target is installed. Installer success is an execution result, not authoritative installed state. Core may persist an Installed or NotInstalled state only when the reconciliation contract supplies sufficient authoritative evidence. Otherwise the resulting state remains Unknown and an existing authoritative state must not be replaced by an assumption.

## Reconciliation contract direction

The dedicated reconciliation provider is application-scoped. Core supplies the managed application identity and approved reconciliation context. The provider returns normalized evidence sufficient for Core to construct an `InstalledApplicationState` or explicitly reports that state cannot be established.

The contract must not:

- become a universal Windows inventory API;
- accept arbitrary executable/script commands from the caller;
- directly write `installed-state.json`;
- infer installation solely from the attempted release;
- manufacture a version when no authoritative version was observed.

## Operation identity

The lifecycle owns one OperationId. Every Core-bound stage request/result that participates in the lifecycle must preserve that identity where its contract supports OperationId. A helper that creates a fresh identity must not be used as a substitute for the lifecycle-owned identity.

## Structured failures

Failures remain structured at stage boundaries. Public composition must not classify failures by parsing human-readable exception messages.

## Cancellation

Cancellation is propagated through the orchestration lifecycle. Cancellation does not by itself prove that an external installer process stopped, nor does it establish installed state.

## 9A exit criteria

- The four lifecycle states above are explicitly represented in implementation contracts/results.
- Verification has a defined input/output boundary.
- Reconciliation has a defined input/output boundary.
- Core owns the state-authority decision and persistence.
- OperationId ownership remains with orchestration.
- No locked phase is reopened merely to compensate for missing composition.
