# Normalized Application Model

## Purpose

Phase 12.4 defines the Core-owned normalization step between source resolution and the existing application-definition/lifecycle contracts.

The model is deliberately not a second manifest schema. It produces the existing application-definition shape used by Test-WintainiumApplicationDefinition, with provider identity/settings copied from normalized source facts and lifecycle policy supplied by a Core-owned policy object.

## Ownership

Source resolution supplies identity facts:

- application identity and name;
- publisher/homepage when available;
- canonical source URI;
- provider identity and contract version;
- provider settings and narrowly defined source context.

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

The resulting ApplicationDefinition uses the existing manifest 1.1 shape:

- ManifestVersion
- Id
- Name
- optional Homepage
- optional Publisher
- Source
- Installer
- Reconciliation
- Release
- Artifact

No lifecycle stage is executed during normalization. No release, artifact, download, verification, installation, or reconciliation decision is made.

## Phase 12.4 constraint

This phase establishes the normalization boundary; it does not yet decide how Core obtains or persists its application policy. That is intentionally left to later Phase 12 work so that policy ownership remains centralized rather than leaking into the GUI or source resolvers.
