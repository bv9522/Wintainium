# Provider Contract Test Harness

## Purpose

Phase 3D establishes a reusable, offline contract-test harness for Wintainium providers. The harness verifies that a provider conforms to the locked Provider Contract without requiring access to the provider's real upstream service.

The harness is test infrastructure, not a production Core command. Wintainium.Core owns the provider contract and execution boundary; the test harness verifies implementations against that contract.

## Scope

The harness covers the provider contract established in Phases 3A–3C:

- provider descriptor validity and constrained module entry point
- contract-version compatibility
- required release/artifact discovery capabilities
- provider resolution
- fixed `Invoke-WintainiumProvider -Request $Request` execution
- valid `ProviderRequest` handling
- exactly one structured `ProviderResult`
- operation-ID correlation
- normalized release and artifact validation
- structured provider failures
- `NoReleasesFound` as a successful outcome
- provider log-event correlation
- provider exceptions converted to structured Core failures

The harness does not test update determination, final artifact selection, downloading, verification, installation, rollback, or CLI/GUI behavior. Those belong to later phases.

## Harness Boundary

A provider under test is supplied through the same descriptor and module-loading path used by Core. The harness must not bypass Core by directly invoking provider functions when testing the Core/provider execution contract.

Conceptually:

```text
Provider descriptor
        |
        v
Plugin registry / resolver
        |
        v
Core provider operation
        |
        v
Invoke-WintainiumProvider -Request $Request
        |
        v
ProviderResult
        |
        v
Core result validation
```

## Provider Fixture Requirements

The offline contract fixture is deliberately deterministic and contains no real network behavior. It supports controlled scenarios required by the harness, including:

- valid release/artifact discovery
- no releases
- structured provider failure
- provider exception
- mismatched operation ID
- malformed normalized release

The fixture represents provider behavior only. It is not a real GitHub provider and must not become a source of network access.

## Reusability Contract

The harness should be reusable by supplying a provider fixture/descriptor rather than embedding provider-specific assertions. Provider-specific behavior, upstream API semantics, authentication, and source-specific metadata remain outside the generic contract suite.

A future real provider, including the Phase 3E GitHub Releases provider, should be able to run the same generic contract suite in addition to its provider-specific integration tests.

## Network Policy

The generic contract harness is offline by design. A provider must be capable of being tested with deterministic fixture inputs without contacting an upstream service.

Real network behavior belongs to provider-specific tests and to the later application workflow. The existence of a provider contract test harness must never weaken Core's offline boundaries.

## Failure Semantics

Contract violations are test failures. The harness must not silently normalize an invalid provider result into a passing result.

The provider implementation may return a structured provider failure where the contract permits one. Core validation failures remain distinct from provider-declared statuses.
