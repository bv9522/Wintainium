# Architecture Decision — Windows Registry Enumeration Boundary

## Status

Accepted for the current module and release-packaging architecture.

## Decision

Keep the Windows uninstall-registry readers in Core's review-only identity-discovery workflow and in the Windows reconciliation plugin as separate implementations for now. Do not introduce a shared registry-enumeration module solely to remove the duplicated traversal.

This is an intentional boundary decision, not a claim that the two readers have identical responsibilities or that duplication is inherently desirable. Revisit it if Wintainium establishes a supported shared-module dependency that can be packaged, loaded, versioned, and tested as part of both module boundaries.

## Evidence

The current implementation has two live readers:

- `Get-WintainiumApplicationRegistryIdentityCandidates` in Core.
- The default registry reader inside `Get-WintainiumWindowsInstalledApplicationCandidates` in the `Wintainium.reconciliation.windows-installed-application` plugin.

Both inspect the three Windows uninstall-registry locations (HKLM 64-bit, HKLM 32-bit, and HKCU native) and retrieve overlapping registration fields. The older `Get-WintainiumWindowsUninstallCandidates.ps1` helper from the earlier inventory is absent from the current branch tree; it is not a live implementation or a justified deletion target.

The workflows remain deliberately different:

- Core discovery ranks possible identity matches for review. Its candidates are non-authoritative, require explicit user confirmation, and expose discovery-specific partial-read errors.
- The reconciliation plugin evaluates manifest-configured predicates, MSI product-code evidence, and its separately governed identity/executable corroboration rules. It owns authoritative installed-state candidate evaluation and its own incomplete-evidence behavior.
- The desktop service presents suggestions and applies only an explicit user-confirmed choice. It is not a third raw registry reader.

## Module and packaging boundary

Core dot-sources its own private scripts from its module directory. The reconciliation implementation is a separately described plugin with its own entry point. The release package builder copies the Core tree and plugin tree as separate package assets; the current package contract does not define a shared runtime module, dependency declaration, versioning rule, or common loader path for code consumed by both.

Extracting the reader now would therefore create a new cross-module dependency and packaging/loading contract. Merely placing a helper in a convenient repository directory would not prove that both separately loaded components can resolve it in development, packaged, and installed layouts. A helper that is available only in the source checkout is not a valid architectural consolidation.

## Constraints

- Preserve the distinct discovery and reconciliation workflows, matching algorithms, authority levels, result contracts, and diagnostics.
- Do not let review-only candidate scores or user suggestions become authoritative installed-state evidence.
- Do not route plugin behavior through Core private implementation details or bypass the plugin contract.
- Keep the duplicated OS-specific registry traversal narrow. Do not copy matching policy, scoring, or workflow decisions between the readers.
- Preserve test seams such as the reconciliation plugin's injectable registry reader and Core's supplied registry-entry input.
- Do not delete or rename the absent legacy helper based on stale inventory.
- Reconsider extraction only alongside an explicit shared-module design covering dependency ownership, module loading, package inclusion, compatibility/versioning, and tests against both source and installed package layouts.

## Consequences

The current small amount of low-level duplication is accepted to preserve independent module ownership and avoid introducing an unsupported runtime dependency. This is preferable to a superficial deduplication that makes packaged plugin loading fragile or couples the plugin to Core internals.

The decision does not prohibit a future shared Windows-platform utility module. It requires that such a module become a first-class, tested packaging dependency before either reader consumes it.
