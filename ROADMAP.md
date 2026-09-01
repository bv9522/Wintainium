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

Phase 4 ends at a structured, explainable update decision. It does not download
artifacts, verify downloaded bytes or signatures, select installers, or execute
installation. Those responsibilities belong to later phases.

## Phase 5 — Download engine

- Download selected artifacts through a controlled Core-owned boundary.
- Apply download safety and destination policies.
- Preserve recoverability and structured operation results.

## Phase 6 — Installer engine

- Select compatible installer plugins.
- Verify downloaded artifacts before execution.
- Execute installation or update operations through controlled installer
  boundaries.
- Preserve recoverability and structured operation results.

## Phase 7 — Orchestration

- Compose discovery, decision, download, verification, and installation into
  end-to-end application update workflows.
- Support multiple-application and update-all workflows.
- Add scheduling and policy-driven automation where appropriate.

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
