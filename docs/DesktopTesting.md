# Desktop Testing & Integration Hardening

Phase 11J keeps desktop verification split between deterministic automated probes and a small WinUI interaction checkpoint.

## Automated desktop probe

`tools/Wintainium.Desktop.EngineProbe` is the presentation-boundary integration probe. It verifies:

- the four-command Core allow-list;
- in-process PowerShell hosting;
- structured manifest result shape;
- application model mapping and preservation of `Unknown` state;
- collection sorting and filtering;
- List/Grid view-model state;
- release and artifact mapping;
- explicit completed/failed/cancelled operation-state mapping;
- structured diagnostic code/path/message preservation;
- session-scoped desktop settings defaults and mutation;
- the desktop cancellation token boundary.

The probe must not parse terminal output or depend on private Core lifecycle objects.

## Manual WinUI checkpoint

The desktop application remains responsible for interaction and window-lifecycle behavior that is not meaningfully exercised by the console probe.

The 11J checkpoint covers:

1. Launch Wintainium and confirm the main window opens normally.
2. Switch between List and Grid without losing the application collection.
3. Open Sort & Filter, apply a sort/filter, cancel the dialog, and confirm cancellation leaves the existing query unchanged.
4. Open Settings, switch through all five categories, and return to Appearance.
5. Change Theme and Visual Style, leave Appearance, return, and confirm session values remain.
6. Close and reopen Settings while the application remains open; confirm the same session values remain.
7. Close Settings, reopen Wintainium, and confirm the session-only settings return to System + Windows 11.
8. Open application Details from List and Grid and confirm the details window is tracked/reused rather than duplicated for the same application.
9. Start release discovery, confirm the activity indicator and Cancel control become active, then exercise completion/failure/cancellation as available from the selected manifest.
10. Close an application Details window during an active operation and confirm the window closes cleanly without leaving the application in a broken state.
11. Close the main window and confirm child Details/Settings windows do not remain orphaned.

## Install launch responsiveness and card transparency follow-up

- [ ] On a fresh install using a GitHub Releases provider, verify that the official installer opens promptly after confirmation. The install lifecycle now defaults to one newest-first release page for that provider; an explicit manifest `source.settings.maxPages` value remains respected.
- [ ] Confirm that the selected release still contains a compatible artifact for the machine architecture and declared artifact formats. If a project needs older release history to find a compatible artifact, set `maxPages` explicitly to a suitable value in its manifest.
- [ ] Compare Grid and List cards in Windows 11 Light and Dark and in every other visual appearance. Card surfaces should have the same transparency in both layouts, preserve each theme's color palette, and keep text readable.
- [ ] Recheck Frutiger Metro's dark crimson card surface and all theme transitions to ensure the shared transparency does not bleed into other theme artwork or colors.

## Phase 14F — Install/update and settings acceptance

Run this checkpoint against the current Release build after pulling the latest
`phase-14-gui-productization` branch. Use a disposable/test application where
possible; do not cancel an installer on a machine where interruption could
damage important work.

### Confirmation preferences

1. In Settings > General, leave "Confirm before installing or updating software"
   enabled. Start an install and verify the confirmation dialog appears before
   lifecycle activity begins. Choose Cancel and verify no operation starts.
2. Repeat for Run Update: the same preference must gate the operation before
   lifecycle activity begins.
3. Disable that preference, repeat an available install/update action, and verify
   the confirmation dialog is skipped.
4. Enable "Confirm before removing software", choose Remove Software, and verify
   the dialog explains that this removes the app from Wintainium's collection
   rather than uninstalling it from Windows. Cancel and verify the collection is
   unchanged.
5. Disable removal confirmation and verify removal proceeds without that dialog.
   Use only a test collection entry.

### Authoritative state and cancellation

6. Complete a normal install and verify Details reports the Core result, then
   reports authoritative installed state. Verify Dashboard reflects the same
   installation state/version.
7. Complete a normal update and verify Details and Dashboard agree on the
   reconciled version/update state.
8. If a safe cancellable test operation is available, cancel during lifecycle
   execution. Verify the operation result says cancelled, but Wintainium still
   attempts authoritative state refresh and reports the resulting state rather
   than assuming no machine changes occurred.
9. If a controlled failure can be induced safely, verify the operation error
   remains visible and the application still attempts authoritative state refresh.
10. Confirm native installer/UAC UI remains owned by Windows/the installer and
    Wintainium does not display invented installer-progress percentages.

### Settings honesty and theme regression

11. Settings > General and Updates should expose the two implemented confirmation
    preferences; startup, close-after-operation, notification, automatic-check,
    and automatic-install options should be clearly marked as not available yet,
    not presented as functioning toggles.
12. Switch among the existing visual styles and verify the settings changes did
    not alter theme assets, fonts, title bars, or dialog styling. Report any
    reproducible cross-theme bleed separately.

Record which cases were run and any observed mismatch. Do not use a failed or
unavailable test as evidence that the corresponding behavior passed.

## Regression boundary

PowerShell/Pester remains authoritative for the Core engine. No Pester run is required for 11J unless desktop hardening exposes a defect that requires a Core/PowerShell change.