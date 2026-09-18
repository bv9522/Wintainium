# Public Application Update Result Contract

## Phase 10B — Public Result

The public `Invoke-WintainiumApplicationUpdate` command returns a presentation-neutral,
stable result projection over the internal lifecycle result.

### Top-level result

- `OperationId` — Core-generated correlation identifier.
- `IsSuccessful` — true only when the lifecycle completed successfully.
- `WasCancelled` — true when cancellation stopped the lifecycle.
- `Status` — `Completed`, `Failed`, or `Cancelled`.
- `ApplicationId` — manifest application identity when definition validation produced one; otherwise null.
- `Stages` — ordered public stage summaries.
- `Errors` — aggregate structured errors emitted by lifecycle stages and the lifecycle boundary; callers should use this collection for error enumeration.
- `Warnings` — structured warnings.
- `LogEvents` — structured diagnostic events.
- `Error` — the lifecycle's terminal structured error when one exists; otherwise null. This is a convenience field for the terminal failure, while `Errors` remains the enumerable error collection.

### Stage summary

Each entry in `Stages` contains only public lifecycle information:

- `Sequence`
- `Name`
- `Status`
- `IsSuccessful`
- `WasCancelled`
- `Error`

Internal stage-operation state, stage factories, dependency objects, provider requests,
download requests, installer requests, reconciliation requests, and private result
objects are not exposed.

### Status mapping

- successful lifecycle → `Completed`
- cancelled lifecycle → `Cancelled`
- unsuccessful non-cancelled lifecycle → `Failed`

Cancellation is represented explicitly at the public boundary even though internal
orchestration operation state continues to use its existing Pending/Running/Failed/
Completed vocabulary.

### Stability rule

The public result is a projection, not a pass-through of the internal orchestration
object. Internal implementation properties may change without becoming public API.
Consumers should use documented properties and structured error codes rather than
parse formatted output or exception messages.

### Collection semantics

`Stages`, `Errors`, `Warnings`, and `LogEvents` are always arrays, including when no entries exist. `Error` is a single object or `$null`; it is not an array.

The public projection copies only documented values from internal lifecycle results. Additional properties present on lifecycle, stage, execution, or private result objects are intentionally discarded rather than forwarded.
