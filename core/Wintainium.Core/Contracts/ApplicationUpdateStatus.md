# Application Update Status Contract

## Purpose

The application update status operation is the read-only Core boundary for
presentation clients that need to show installed and update state.

The operation composes existing Core-owned validation, release discovery,
authoritative installed-state observation, release eligibility, target
resolution, and update-decision logic. It does not download, verify, install,
or reconcile anything.

## Input

- ManifestPath — absolute path to the validated application manifest.
- StateRoot — authoritative installed-state root.
- MachineArchitecture — normalized target-machine architecture.
- PluginRoot — optional plugin root.
- SchemaPath — optional manifest schema path.
- OperationId — optional correlation identifier.

## Result

The stable public result contains:

- OperationId
- IsSuccessful
- Status
- Manifest
- InstalledState
- Decision
- Errors
- Warnings
- LogEvents

Decision is a public projection. It contains only:

- IsUpdateAvailable
- ReasonCode
- Reason
- IsDeterministic
- SelectedRelease

SelectedRelease is null unless Core selected an update target and contains
only ReleaseId, Version, Channel, and PublishedAt.

Private release-eligibility and target-resolution objects are not part of the
presentation contract.

## Status semantics

- UpdateAvailable — Core selected a newer eligible release and selectable
  artifact.
- NoUpdateAvailable — discovery completed and Core found no selectable
  update.
- ApplicationNotInstalled — authoritative state established that the
  application is not installed; no update decision is made.
- DecisionIndeterminate — Core could not make a deterministic decision.
- ProviderDiscoveryUnsuccessful — release discovery did not complete
  successfully.

A presentation client must preserve DecisionIndeterminate and failed
discovery as unknown/indeterminate state. It must not infer an update,
installation state, or version ordering from human-readable messages.

## Phase boundary

This command is observation and decision presentation only. Download,
verification, installer selection, installation, and reconciliation remain
owned by their respective Core stages and the public update lifecycle.
