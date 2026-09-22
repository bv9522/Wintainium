# Architecture Decision — Source Resolution Boundary

## Status

Accepted for Phase 12B.

## Decision

Wintainium will introduce an additive Source Resolution capability at the provider boundary.

Source resolution is responsible for turning an official source/release/download URL into normalized source facts. It is not a replacement for the existing Provider Contract v1 release/artifact discovery operation.

Existing providers that do not advertise source resolution remain valid.

## Reason

The product vision requires Add Software to accept an official source URL rather than requiring the user to author a Wintainium manifest.

GitHub, structured vendor download pages, APIs, feeds, and interactive vendor portals expose fundamentally different upstream mechanisms. A single vendor-specific implementation in Core would not scale, while a universal arbitrary-webpage scraper would be unreliable and unsafe.

An optional source-resolution capability provides a stable Core boundary while allowing each source implementation to use the appropriate upstream mechanism.

## Consequences

Positive:

- Existing Provider Contract v1 remains intact.
- GitHub can provide a deterministic first vertical slice.
- Structured vendor download pages can later be handled by generalized resolution machinery.
- Unsupported or interactive sources can fail explicitly without corrupting application state.
- The GUI remains unaware of provider-specific configuration.
- Core continues to own lifecycle policy and artifact selection.

Constraints:

- Source resolution introduces a new structured contract that must be validated like every other plugin boundary.
- Source resolution cannot guarantee universal web-page understanding.
- Provider implementations may still need source-specific parsing behind the boundary.
- Application-definition construction and persistence must be addressed separately.

## Explicit non-decision

This decision does not authorize arbitrary web scraping.

Phase 12.5 will establish the supported structured-page resolution strategy after the GitHub vertical slice proves the normalized boundary.

## Relationship to existing decisions

This decision preserves:

- Decision #002: Managed Application remains the central domain entity.
- Decision #003: Provider and Installer contracts remain separate.
- Decision #005: Plugins communicate through Core.
- Decision #011: Providers discover releases/artifacts; Core decides.
- Decision #012: Provider results use normalized Core models.
- Decision #015: Provider network behavior remains outside the local manifest engine.
- Decision #017: Provider operations use fixed module contracts.
- Decision #018: Provider operations return exactly one structured result.
- Decision #019: Core validates provider result contracts.
