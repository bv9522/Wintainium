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

## Regression boundary

PowerShell/Pester remains authoritative for the Core engine. No Pester run is required for 11J unless desktop hardening exposes a defect that requires a Core/PowerShell change.