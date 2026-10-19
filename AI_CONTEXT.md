# AI Development Context

This file is the compact orientation guide for agents and contributors working on
Wintainium. It describes the repository as it exists on the current development
line; historical phase documents remain historical records.

## Required reading order

1. `PROJECT.md`
2. `ROADMAP.md`
3. `ARCHITECTURE.md`
4. Relevant current contracts and tests
5. Relevant implementation files

## Non-negotiable architecture

- **Manifest describes.**
- **Provider discovers.**
- **Core decides.**
- **Download obtains.**
- **Verification establishes trust.**
- **Installer applies.**
- **Orchestration coordinates.**
- **UX presents.**

The interface presents the engine; it does not become the engine.

PowerShell Core remains authoritative for lifecycle, policy, provider behavior,
artifact selection, verification, installer execution, reconciliation,
cancellation, and managed installed state. The WinUI client consumes documented
structured results through the C# adapter and application/presentation
services.

Never move Core lifecycle policy into WinUI merely to make a feature easier to
implement.

## Current repository state

- Phases 1–10: complete and locked.
- Phase 11: WinUI 3 desktop foundation and client boundaries complete and locked.
- Phase 12: desktop/Core integration complete and locked.
- Phase 13: GUI productization foundation complete/superseded.
- Phase 13.5: production installers/package formats complete and locked.
- **Phase 14: GUI Productization is current and in progress.**
- **Phase 14.5: First-Install Capability is complete and locked.**
- Phase 14E onboarding and 14H visual system are complete; the visual system is
  frozen except for reproducible defects.
- **Phase 14F: Update Experience is the current engineering focus.**

The real 7-Zip update is the reference end-to-end validation of the architecture:
Wintainium discovers the release, makes the update decision, downloads and
verifies the artifact, selects and invokes the installer, handles Windows
elevation, and reconciles authoritative installed state afterward.

## Current desktop product

The production desktop client currently has:

- Dashboard application collection with List/Grid presentation
- Sort/filter presentation
- Add Software source URL onboarding
- structured onboarding outcomes and recovery
- Application Details
- Install / Check for Updates / Run Updates
- operation status, lifecycle stages, errors, warnings, release information,
  and notes
- automatic application icons
- user-selected icon overrides with reset-to-automatic behavior
- Remove Software from the Wintainium collection
- authoritative collection refresh after relevant operations

The Dashboard context menu intentionally contains only **Remove Software**.
Do not reintroduce context-menu actions that simply open Details; left-click
already provides that navigation/action hub.

## Current onboarding contract

`Invoke-WintainiumApplicationOnboarding` is the Core boundary for source URL
onboarding. Core owns URI validation, source-resolution provider selection,
ambiguity handling, default lifecycle-policy resolution, application
normalization, and manifest persistence.

The desktop presents those structured results. It does not resolve providers,
construct manifests, choose installers, or persist application definitions
itself.

## Current icon model

Automatic icon metadata and a user-selected override are separate concepts.
The automatic icon remains intact when an override is selected. Icon changes
must flow through the Core/application persistence contract; WinUI must not
rewrite manifests directly.

## Current removal semantics

Remove Software means remove the managed application definition from the
Wintainium collection. It does **not** mean uninstall the Windows application.
Any future uninstall capability must use the lifecycle/installer contract.

## Update experience rule

Do not create a fake Wintainium installer progress bar. Native installers own
their own UI/progress when Wintainium launches them. Wintainium may show
lifecycle/activity before and after native installer execution and must
reconcile authoritative installed state afterward.

Cancellation of the desktop operation token must not automatically cancel
post-operation reconciliation. An installer can have changed machine state
before cancellation is observed. After a structured install/update result—or
when cancellation interrupts the operation before a result is returned—the
desktop should attempt authoritative reconciliation with an independent token.
If reconciliation fails, present that failure clearly rather than implying
that cancellation proves no machine changes occurred.

## Phase 14 working order

1. 14C/14D: focused Dashboard and Details acceptance; fix only demonstrated gaps.
2. 14F: update/install lifecycle presentation, cancellation, reconciliation, and
   refresh consistency.
3. 14G: audit every Settings control for a real, observable consumer; defer
   controls whose underlying capability does not yet exist.
4. 14I: keyboard, focus, automation/accessibility, resizing, DPI, dialog, UAC,
   cancellation, and error-state audit.
5. 14J: full desktop/Core regression, real onboarding/install/update evidence,
   architecture/UX audit, cleanup, and phase lock.

Do not reopen completed onboarding or frozen visual styling without a
reproducible defect. Historical test counts are historical evidence only and
must not be described as rerun at the current commit unless they actually were.

## Public Core surface

The current module manifest exports these functions:

- `Get-WintainiumManifest`
- `Get-WintainiumApplicationInstalledState`
- `Invoke-WintainiumApplicationReconciliation`
- `Set-WintainiumApplicationReconciliationSettings`
- `Test-WintainiumApplicationDefinition`
- `Get-WintainiumApplicationRelease`
- `Get-WintainiumApplicationUpdateStatus`
- `Invoke-WintainiumApplicationUpdate`
- `Invoke-WintainiumApplicationInstall`
- `Invoke-WintainiumApplicationOnboarding`
- `Set-WintainiumApplicationIconOverride`
- `Remove-WintainiumApplication`

Treat the module manifest and `Wintainium.Core.psm1` export list as the
authoritative list. Do not repeat older four-command/seven-command claims from
historical documentation.

## Development

Preferred desktop Release build:

```powershell
dotnet build .\src\Wintainium.Desktop\Wintainium.Desktop.csproj -c Release
```

Run focused Pester tests while developing and the full suite when explicitly
requested for a regression checkpoint.

When changing a contract, update the relevant documentation and tests. Do not
rewrite historical phase/audit documents merely to make their old conclusions
look current; mark current-facing documents accurately instead.
