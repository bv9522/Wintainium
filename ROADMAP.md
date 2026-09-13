# Roadmap

This roadmap is directional and may change through documented decisions.

## Foundation

- Establish repository conventions and architecture documentation.
- Decide the public PowerShell module contract and plugin contract before
  implementing providers.
- Add development, test, and release policies.

## Phase 3 — Provider architecture

- 3A: Provider Contract v1
- 3B: Provider resolution and capability enforcement
- 3C: Fixed provider operation boundary
- 3D: Reusable offline provider contract-test harness
- 3E: First real reference provider — GitHub Releases
- 3F: Documentation and final Phase 3 lock

GitHub is the first reference provider, not the universal source model. Future
providers are expected to support official vendor websites, vendor APIs,
feeds, CDNs, and other authoritative distribution sources without changing the
Core provider boundary.

## Phase 4 — Update discovery and decision engine

- 4A: Validate the update-decision input boundary.
- 4B: Normalize and compare version observations deterministically.
- 4C: Evaluate release eligibility under manifest policy.
- 4D: Evaluate and select a permitted artifact deterministically.
- 4E: Resolve the best eligible release and selectable artifact.
- 4F: Produce the final structured update decision.
- 4G: Integrate provider discovery with the update-decision pipeline.
- 4H: Lock Phase 4 architecture and documentation.

**Status: Complete and locked.** Phase 4 ends at a structured, explainable update decision. It does not download artifacts, verify downloaded bytes or signatures, select installers, or execute installation.

## Phase 5 — Download engine

- 5A: Validate the download request input boundary.
- 5B: Validate URI and destination safety.
- 5C: Perform controlled Core-owned acquisition.
- 5D: Define structured failure and recovery behavior.
- 5E: Define the structured download-result/artifact handoff.
- 5F: Integrate the selected Phase 4 artifact with the download boundary.
- 5G: Audit and lock the Phase 5 architecture and documentation.

**Status: Complete and locked.** Phase 5 acquires the selected Phase 4 artifact through a controlled Core-owned boundary, publishes only completed transfers, cleans partial downloads, and returns structured results. A successful download does not establish artifact trust or installation readiness.

## Phase 6 — Installer engine

- 6A: Validate the installer input boundary.
- 6B: Define installer descriptors and capability validation.
- 6C: Select a compatible installer plugin.
- 6D: Prepare a controlled installer invocation.
- 6E: Own installer process lifecycle, timeout, and cancellation semantics.
- 6F: Produce structured installation results.
- 6G: Integrate installer plugin planning with the controlled process boundary.
- 6H: Audit and lock the Phase 6 architecture and documentation.

**Status: Complete and locked.** Phase 6 owns installer selection and controlled execution boundaries, but it does not perform post-install application-state reconciliation. Artifact verification/trust remains an explicit prerequisite before execution and is not implied by a successful Phase 5 download or Phase 6 structural input. A targeted 6E process-completion race correction is covered by the Phase 7I regression checkpoint without changing the locked process contract.

## Phase 7 — Orchestration

- 7A: Establish the orchestration input boundary and parent operation context.
- 7B: Define deterministic orchestration stage sequencing.
- 7C: Define immutable orchestration operation state.
- 7D: Define stage state transitions and fail-fast failure commitment.
- 7E: Define the cancellation control-flow boundary.
- 7F: Define Core-owned single-stage execution.
- 7G: Coordinate single-stage execution with state transitions.
- 7H: Coordinate the complete multi-stage workflow.
- 7I: Coordinate lifecycle initialization and workflow delegation.
- Compose discovery, decision, download, verification, and installation into
  end-to-end application update workflows without duplicating stage policy.
- Define recoverable partial-operation semantics.
- Add multiple-application and update-all workflows after the single-application
  lifecycle is stable.
- Add scheduling and policy-driven automation only after the underlying
  orchestration contract is stable.

**Status: 7A–7I implemented, validated, and locked.** The current single-application lifecycle establishes deterministic stage sequencing, immutable state transitions, explicit cancellation control flow, structured failures, parent-operation correlation, and a Core-owned lifecycle entry boundary. The mandatory verification stage remains explicit and is not bypassed by orchestration.

## Phase 8 — UX and documentation

- Refine the PowerShell command-line experience.
- Complete user-facing documentation and operational guidance.
- Establish release packaging and upgrade procedures.
- Prepare the engine for a future C#/.NET GUI without moving business rules
  into the GUI.

## Version 1.0 — Desktop experience

- C#/.NET GUI over the PowerShell engine
- Plugin manager
- Automatic scheduling and settings
- Release packaging and upgrade path
