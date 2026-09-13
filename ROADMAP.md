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

## Phase 8 — UX, documentation, release preparation, and GUI readiness

### 8A — Public CLI contract audit

- Inventory the actual exported PowerShell surface.
- Distinguish stable user-facing operations from internal implementation helpers.
- Define the presentation-neutral request/result boundary for PowerShell and the
  future C#/.NET client.
- Establish structured error semantics and operation correlation requirements.
- Identify the missing public orchestration entry boundary.
- Prevent internal stage/provider/installer contracts from leaking into clients.

**Status: Complete.** The public-contract decision is recorded in
`docs/PublicPowerShellContract.md`. The current four exported functions were
audited; three remain intended public operations, while
`New-WintainiumInstallerRequest` is classified as a low-level implementation
operation that should leave the stable user-facing surface. The locked Phase 7
lifecycle is identified as the missing public end-to-end operation and will be
wrapped by a purpose-built public command only after its real internal stage
composition boundary is established.

### 8B — CLI UX and public result contract

- Establish the common structured result contract for supported public commands.
- Refine public parameter names, validation, comment-based help, and examples.
- Establish a Core-owned composition seam for the real end-to-end orchestration
  stage executors before exposing the public update command.
- Expose the purpose-built public orchestration command only after that seam can
  supply real stage bindings without leaking `StagePlan`, `CancellationContext`,
  stage factories, provider requests, download requests, or installer requests
  to callers.
- Standardize stable error categories and machine-readable result data.
- Add appropriate human-readable and machine-readable presentation without
  putting presentation logic into Core business rules.
- Add contract tests for the supported public command surface.

**Status: In progress.** `docs/PublicResultContract.md` defines the result
boundary, and contract coverage has been added for the three currently
supported public commands. The Phase 7 lifecycle is deliberately not exposed
as a public command yet because the repository currently contains the generic
lifecycle machinery but not a concrete Core-owned stage-composition seam for
binding the seven real application-management stages. Exposing it now would
force CLI/GUI callers to construct internal orchestration dependencies and
would violate the presentation-neutral boundary.

### 8C — User documentation and operational guidance

- Write the normal-user guide and CLI reference from actual implemented
  behavior.
- Document configuration, manifests, plugins, update operations, failures,
  cancellation, logs, and troubleshooting.
- Keep architecture/developer documentation aligned with public contracts.

### 8D — Release boundary and packaging

- Define deterministic release package contents and layout.
- Establish authoritative version metadata and release validation.
- Validate required Core, schema, plugin, manifest/resource, and documentation
  assets without bundling development-only material.

### 8E — Upgrade and persistence contract

- Classify program files, user configuration, application state, logs, caches,
  manifests, and temporary artifacts from the actual implementation.
- Define safe replacement/preservation behavior for upgrades.
- Validate a supported N→N+1 upgrade path without introducing speculative
  persistence infrastructure.

### 8F — GUI readiness audit and Phase 8 lock

- Verify that a future C#/.NET GUI can consume the public engine boundary
  without reproducing business rules.
- Confirm the GUI seam is presentation/client code over the PowerShell engine.
- Complete regression, documentation, package, and upgrade validation.
- Lock Phase 8 only when the public contract, release boundary, and upgrade
  behavior are coherent and tested.

## Version 1.0 — Desktop experience

- C#/.NET GUI over the PowerShell engine
- Plugin manager
- Automatic scheduling and settings
- Release packaging and upgrade path
