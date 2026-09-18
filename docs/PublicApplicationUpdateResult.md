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
- `Errors` — structured errors owned by the lifecycle/public boundary.
- `Warnings` — structured warnings.
- `LogEvents` — structured diagnostic events.
- `Error` — terminal structured error when the lifecycle itself has one; otherwise null.

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
