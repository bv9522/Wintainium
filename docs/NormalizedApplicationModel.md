# Normalized Application Model

## Purpose

Phase 12.4 defines the Core-owned normalization step between source resolution and the existing application-definition/lifecycle contracts.

The model is deliberately not a second manifest schema. It produces the existing application-definition shape used by Test-WintainiumApplicationDefinition, with provider identity/settings copied from normalized source facts and lifecycle policy supplied by a Core-owned policy object.

## Ownership

Source resolution supplies identity facts:

- `ApplicationId` — provider-assigned stable Wintainium application identifier, distinct from a display name and derived from stable upstream/source identity;
- `Name` — primary display name;
- optional `Aliases` — alternate names explicitly established by the resolver;
- publisher and homepage when available;
- `SubmittedUri` — the URL the user supplied to onboarding;
- `CanonicalUri` — the resolver's canonical source identity URI;
- provider identity and contract version;
- provider settings, which retain the provider's upstream locator;
- narrowly defined, provider-owned source context.

Aliases are name-level hints only. They must not be used as substitutes for package family names, product codes, executable paths, or other installation identifiers. Core preserves aliases supplied by the resolver; it does not invent them from arbitrary page text.

Core-owned application policy supplies:

- installer plugin and settings;
- reconciliation plugin and settings;
- release channel;
- artifact formats;
- artifact architectures;
- unknown-architecture policy.

The source resolver never invents installer or artifact policy. The desktop client never supplies provider-specific settings.

## Boundary

New-WintainiumApplicationDefinitionFromSource accepts:

- Source — normalized source-resolution facts;
- Policy — Core-owned application policy;
- optional OperationId.

A successful result returns:

- OperationId
- IsSuccessful
- Status = Resolved
- ApplicationDefinition
- Errors
- Warnings
- LogEvents

A missing or incomplete policy is a structured failure rather than an inferred installer or lifecycle configuration.

## Relationship to the existing manifest

The resulting ApplicationDefinition uses manifest 1.2, with additive optional source identity fields. The schema continues to accept existing 1.1 manifests:

- `Id` and `Name` remain the stable application identifier and primary display name;
- optional `Aliases`, `Homepage`, and `Publisher`;
- `Source.submittedUri` preserves the user's supplied URL;
- `Source.canonicalUri` preserves the resolver's canonical source identity;
- `Source.settings` retains provider-specific upstream identity/configuration;
- `Source.pluginId` and `requiredContractVersion` identify the resolver contract.
- Installer
- Reconciliation
- Release
- Artifact

No lifecycle stage is executed during normalization. No release, artifact, download, verification, installation, or reconciliation decision is made.

## Phase 12.4 constraint

This phase establishes the normalization boundary; it does not yet decide how Core obtains or persists its application policy. That is intentionally left to later Phase 12 work so that policy ownership remains centralized rather than leaking into the GUI or source resolvers.
