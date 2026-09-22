# Application Definition Persistence Contract

## Purpose

Phase 12.8 defines durable persistence for a Wintainium-managed application definition. The persisted application definition is the same declarative manifest consumed by Get-WintainiumManifest; persistence does not create a second application-configuration authority.

## Ownership

The local manifest collection is the durable authority for application definitions and source/provider configuration.

Installed application observations remain owned by the existing installed-state.json store. Application definition persistence must never write installed state.

Desktop presentation settings, notes, and transient operation state remain outside this contract.

## File Contract

Application definitions are stored beneath a caller-selected manifest root using the existing .wintainium.json filename convention:

    <ManifestRoot>/
    └── <ApplicationId>.wintainium.json

ApplicationId is taken from the manifest id property. The existing manifest identifier rules prevent path-separator characters and therefore make the derived filename deterministic.

## Write Boundary

The Core private function Set-WintainiumApplicationDefinition accepts an already-normalized application definition and a manifest root.

The function:
1. requires a non-empty application identifier;
2. creates the manifest root when necessary;
3. serializes the definition as JSON;
4. validates the serialized document against the authoritative application manifest schema;
5. atomically replaces the application definition file;
6. returns the persisted path.

A schema-invalid definition is rejected before the destination file is replaced.

## Replacement Semantics

Application identity is keyed by id. Persisting an existing ApplicationId replaces that application's manifest rather than creating a second definition with the same identity.

The existing Get-WintainiumManifest discovery path remains the read boundary. No alternate registry or database is introduced.

## Boundaries

This contract does not:
- discover sources;
- contact providers;
- select releases or artifacts;
- download or install software;
- infer installed state;
- persist installed-state observations;
- persist desktop appearance settings;
- persist update-operation progress.

The persistence boundary is declarative storage only.

## Architectural Relationship

    Source Resolution
           |
           v
    Normalized Application Definition
           |
           v
    Set-WintainiumApplicationDefinition
           |
           v
    <ManifestRoot>/<ApplicationId>.wintainium.json
           |
           v
    Get-WintainiumManifest
           |
           v
    Existing Core lifecycle

This keeps the ownership model explicit:

Manifest describes. Installed state observes. Core decides. UX presents.
