# Provider Contract Test Harness

## Status

Phase 3F.1 documentation: accepted for Phase 3.

The provider contract test harness is the reusable verification boundary for
Wintainium providers. A provider that claims conformance to Provider Contract
v1 should be testable through the same Core-facing contract suite used by the
reference provider.

## Purpose

The harness verifies the behavior that must remain identical across provider
implementations while leaving upstream-specific integration behavior to the
provider's own tests.

The harness is deliberately concerned with the **Core/provider boundary**,
not with the details of a particular upstream service.

## What the harness verifies

A conforming Provider Contract v1 implementation must:

- identify itself as a `Provider` plugin;
- advertise a compatible Provider Contract major version;
- declare the required release and artifact discovery capabilities;
- expose a constrained `.psm1` entry point;
- execute through Core's fixed `Invoke-WintainiumProvider -Request <ProviderRequest>` operation;
- return exactly one structured provider result;
- preserve the Core-supplied `OperationId`;
- return normalized release data rather than provider-specific Core data;
- return normalized artifact candidates with valid required fields;
- preserve structured success, no-data, warning, and failure semantics;
- emit provider log events that retain the Core operation correlation.

## What the harness does not verify

The reusable harness does **not** attempt to prove that an upstream integration
is correct in every provider-specific respect. Those responsibilities remain
with the provider's own unit and integration tests.

Examples include:

- the correctness of an upstream API endpoint or website parser;
- pagination behavior specific to an upstream service;
- authentication mechanisms required by a particular source;
- rate-limit handling and retry policy specific to an upstream service;
- interpretation of vendor-specific release metadata;
- source-specific filtering or artifact-selection heuristics.

The GitHub Releases provider therefore retains its dedicated unit tests in
addition to the reusable contract suite.

## Offline fixture

The reusable harness is exercised against the Phase 3 offline provider
contract fixture. The fixture deliberately produces controlled contract
states without contacting an external service, including:

- valid result;
- empty/no-release result;
- structured provider failure;
- malformed result;
- incorrect operation correlation;
- malformed release data;
- malformed artifact data.

The fixture exists to make contract behavior deterministic and safe to test.
It is not intended to simulate every upstream platform.

## Reference-provider conformance

The GitHub Releases provider is the first real reference implementation. Its
contract suite is pointed at the same reusable harness used by the offline
fixture.

This establishes an important architectural property:

> If the reusable harness cannot test the offline fixture and the first real
> provider through the same Core-facing contract, the harness is not actually
> reusable.

The provider-specific GitHub tests remain separate because they test behavior
that belongs to GitHub rather than to Wintainium's provider contract.

## Network boundary

The reusable contract harness must not require network access merely to verify
Provider Contract v1 behavior. Its fixture inputs are deterministic and local.

A real provider's dedicated integration tests may use network access when that
is necessary to verify the upstream integration. Such tests are not a substitute
for the offline contract suite.

## Provider source neutrality

The harness intentionally contains no GitHub-specific contract assumptions.
Provider Contract v1 is a source-neutral Core boundary.

Future providers may obtain release and artifact information from:

- official vendor websites;
- vendor APIs;
- RSS/Atom or other release feeds;
- update manifests or metadata endpoints;
- CDNs used by the official publisher;
- GitHub Releases;
- other authoritative distribution mechanisms.

A new provider should be able to conform to Provider Contract v1 without
requiring a new Core operation merely because its upstream transport differs.

## Adding a new provider

A new provider should be developed in this order:

1. Define its descriptor and supported Provider Contract version.
2. Implement the fixed provider operation.
3. Add provider-specific unit tests for upstream behavior.
4. Point the reusable contract harness at the provider.
5. Run the full Pester suite.
6. Document any genuinely new Core-level requirement as an architecture
   decision before changing the contract.

A provider should not weaken or bypass the reusable harness to accommodate
source-specific behavior. If a source requires a capability that is outside
Provider Contract v1, that requirement should be evaluated explicitly as a
future contract or architecture change.

## Phase 3 boundary

Phase 3 establishes **discovery**, not the complete application-management
lifecycle. Providers discover upstream release and artifact candidates. They do
not decide whether an update is required, download artifacts, verify downloaded
bytes, install software, or orchestrate the managed-application lifecycle.
Those responsibilities belong to later phases.
