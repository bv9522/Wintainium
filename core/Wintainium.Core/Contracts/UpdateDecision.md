# Phase 4E Update Decision Contract

## Purpose

Phase 4E defines the final structured update-decision result. Phase 4F
implements the pure Core operation that produces that result from validated
Phase 4 input, release eligibility, and target resolution. The operation
observes data and returns a decision; it does not perform the update.

## Inputs

- `UpdateDecisionInput` — the validated Phase 4A input boundary.
- `MachineArchitecture` — the normalized target-machine architecture.

The provider result is consumed as an already-completed observation. Phase 4F
does not invoke a provider, use the network, download data, verify bytes,
choose an installer, or execute an installer.

## Status and Availability

| Status | `IsUpdateAvailable` | Meaning |
| --- | --- | --- |
| `UpdateAvailable` | `true` | A release and one permitted artifact were resolved. |
| `NoUpdateAvailable` | `false` | Discovery completed, but no eligible release or selectable artifact exists. |
| `ApplicationNotInstalled` | `false` | The state source established that the application is not installed. |
| `DecisionIndeterminate` | `$null` | Installed state or version ranking is insufficient for a safe decision. |
| `ProviderDiscoveryUnsuccessful` | `$null` | Upstream discovery did not complete successfully. |

`SelectedRelease` and `SelectedArtifact` are populated only for
`UpdateAvailable`. The result always retains the Phase 4C and 4E observations
needed to explain the outcome.

## Phase Boundary

Phase 4F answers: `Is an update available, and if so, what is its selected target?`

The result is not download authorization or execution authority. Downloading
begins in Phase 5; installation begins in Phase 6.
