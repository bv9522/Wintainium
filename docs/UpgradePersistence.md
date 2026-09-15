# Wintainium Upgrade and Persistence Contract

## Purpose

Phase 8E defines the minimum persistence and upgrade boundary required for a supported Wintainium installation. It establishes where Wintainium-managed state belongs, what a release may replace, what must survive an engine upgrade, and how authoritative installed-application state reaches the locked Phase 4 update-decision boundary.

This phase deliberately defines a small contract rather than introducing a general database, synchronization service, telemetry system, or Windows-wide software inventory framework.

## Ownership classes

| Class | Examples | Upgrade treatment |
| --- | --- | --- |
| Program files | Core module, schemas, shipped plugins, release documentation | Replace from the new release package. |
| User configuration | User-selected paths, policies, enabled plugins, and future settings | Preserve; migrate only through an explicit versioned migration rule. |
| Installed application state | Authoritative observation of managed application installations | Preserve across an engine upgrade; update only through an explicit state write performed by the engine. |
| Manifests | Application-management definitions supplied by the user or a manifest source | Preserve as user/source data unless an explicit manifest-management policy replaces them. |
| Logs | Structured operation diagnostics | Preserve across upgrade; retention/rotation is separate policy. |
| Caches and temporary data | Provider/download caches, incomplete transfers, transient staging data | Caches may be invalidated; temporary data is disposable and not durable state. |

The release package itself is program content. It must not contain user configuration, installed state, logs, caches, or temporary application data.

## Program-file boundary

An engine upgrade replaces the program-file tree represented by the release package. The replacement target is the engine installation location, not the user's data locations.

The release package must remain self-contained with respect to its documented runtime assets. User data must not be copied into the package merely to make an upgrade convenient.

An upgrade must not silently delete user-owned configuration, manifests, logs, or authoritative installed state.

## Persistence boundary

Phase 8E establishes the conceptual persistence roots but does not require a specific database technology.

The durable state boundary consists of:

- **Configuration state** — user choices and Wintainium policies.
- **Installed application state** — one authoritative record per managed application identity.
- **Manifest data** — user/source-owned application definitions when retained locally.
- **Logs** — structured operation records and diagnostics.

Caches and temporary files are outside the durable contract. They may be recreated or discarded without changing the authoritative meaning of a managed application.

The current implementation uses a small local JSON store for installed application state. The storage technology is an implementation detail and must not leak into Phase 4 decision logic or the public command contract.

## Authoritative installed state

The authoritative Core representation is the existing `InstalledApplicationState` contract. Its stable application identity is the manifest `ApplicationId`; it does not use provider-specific identifiers as a second Core identity.

A persisted record represents the latest state established by a Wintainium-managed state writer. The persistence layer is responsible for durable storage and retrieval; the managed-state source exposes that persisted observation to Core composition; Core update-decision logic is responsible for interpreting the normalized state.

The normalized state has these fields:

- `ApplicationId`
- `InstallationState` (`Installed`, `NotInstalled`, or `Unknown`)
- optional `Version`
- optional `VersionSource`
- `Architecture` (`x86`, `x64`, `arm64`, `neutral`, or `unknown`)
- `Channel` (`stable`, `prerelease`, or `unknown`)
- optional `InstallationLocation`

Unknown observations remain unknown. Persistence must not turn missing data into a guessed value.

## State-source boundary

The current supported state source is deliberately narrow: the Core managed-state source reads the authoritative Wintainium state record for a requested `ApplicationId`. It does not scan Windows, infer installation state from arbitrary files, or introduce a second identity system.

The persisted record is authoritative only when it was established by an explicit Wintainium state writer or a future state source that conforms to this contract. A missing record returns `Unknown`.

Future concrete sources may use registry/uninstall information, MSI, AppX/MSIX, installer records, portable application records, or another explicitly implemented mechanism. Each source must translate its observation into `InstalledApplicationState` before Core decision logic consumes it.

The first implementation intentionally avoids building a generic inventory framework before a real managed application requires one.

## State write rules

Installed state may be written only after a state source has established the observation or after a completed Wintainium-managed installation/update has a well-defined resulting state.

The engine must not persist an `Installed` record merely because a provider reported a release, a download completed, or an installer process was launched. Likewise, an `Unknown` observation must not be persisted as `Installed`.

A `NotInstalled` record must not carry an invented installed version.

## Read path into Phase 4

```text
Manifest
   +
Managed state source -> InstalledApplicationState <- Persistence
   +
Provider discovery -> ProviderResult
   |
   v
Phase 4 Update Decision
```

`Get-WintainiumApplicationUpdateDecision` is the current Core-owned composition boundary for this path. It obtains release discovery, retrieves installed state by manifest identity, constructs the internal `UpdateDecisionInput`, and delegates the decision to the locked Phase 4 operation.

Persistence and state-source components provide observations. They do not make update decisions. `Get-WintainiumUpdateDecision` remains the sole owner of the Phase 4 decision rules.

The public end-to-end orchestration command must consume this Core-owned state boundary rather than requiring callers to construct installed state, provider results, download requests, installer requests, or orchestration stage objects.

## Missing and stale state

A missing authoritative record is not equivalent to `NotInstalled`. Until a state source establishes the condition, the state is `Unknown` and update orchestration must not guess.

Persisted state may become stale because software can be changed outside Wintainium. A future state-refresh operation may re-observe the application before making an update decision. Staleness policy must be explicit; timestamp presence alone does not prove installation state.

## Upgrade transaction boundary

A supported N→N+1 engine upgrade has this conceptual sequence:

1. Validate the incoming release package.
2. Identify the existing Wintainium program-file root.
3. Preserve durable user/state roots outside that program-file root.
4. Prepare the new program files without modifying durable user state.
5. Switch to the new program files only after required validation succeeds.
6. Retain the previous durable state unchanged unless an explicit migration is required and succeeds.
7. Remove only obsolete program files that belong to the previous release.
8. Leave caches/temporary staging disposable.

The repository now implements this boundary with `tools/Invoke-WintainiumEngineUpgrade.ps1`. The tool accepts a validated release package and an existing program root, stages the complete new program tree beside the existing installation, validates the staged tree independently, switches the directory only after validation succeeds, and removes the previous program tree after the switch. Durable data remains outside the program root and is therefore untouched by the replacement operation.

The switch uses a transaction-specific sibling backup. If the new program directory cannot be activated, the previous program directory is restored. If cleanup of the old program directory cannot complete after a successful switch, the upgrade remains successful but returns the recovery-backup location as a warning rather than falsely reporting an incomplete activation.

The initial implementation intentionally does not migrate or relocate user data. Any future migration must be versioned, explicit, testable, and reversible or safely recoverable.

## Failure and recovery

An incomplete engine upgrade must not be reported as successful. The implemented replacement path validates before switching and retains the previous program tree during the activation step so that a failed switch can restore the prior installation.

Durable state corruption is outside the normal package-replacement path. The upgrade mechanism does not use a partially written configuration or installed-state file as the source for destructive replacement.

## Security boundary

Persistence is storage, not trust. Stored provider metadata, installation locations, and version observations remain untrusted observations. Persistence must not grant permission to execute arbitrary stored paths or bypass Phase 5 verification or Phase 6 installer safety rules.

## Phase boundary

Phase 8E establishes the persistence ownership model, authoritative installed-state boundary, a minimal managed-state source, and the supported N→N+1 upgrade semantics needed by the public engine. It does not implement a general inventory product, cloud synchronization, telemetry, scheduling, update-all behavior, or GUI.

The remaining work is the final end-to-end composition audit. The public update command remains deferred until verification and post-install state reconciliation have concrete composition contracts.
