# Phase 9A — Contract Notes

Phase 9A establishes the lifecycle evidence model before implementation.

- Downloaded is not Verified.
- Verified is required before Installation.
- Installer success is not authoritative installed state.
- Reconciliation is a dedicated, narrow application-scoped evidence boundary.
- Core alone normalizes and persists managed installed state.
- `Unknown` is preserved when authoritative evidence is insufficient.
- A selected release is never evidence that its version is installed.
- The orchestration lifecycle owns OperationId and cancellation semantics.
- Public composition must not recreate internal stage machinery.

The Phase 8 foundations remain locked unless a demonstrated incompatibility is found.