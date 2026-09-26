namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationUpdateDecisionResult(
    string OperationId,
    bool IsSuccessful,
    string? Status,
    WintainiumApplicationUpdateDecisionModel? Decision,
    WintainiumInstalledStateObservation? InstalledState,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    WintainiumOperationState OperationState = WintainiumOperationState.NotStarted);

internal sealed record WintainiumApplicationUpdateDecisionModel(
    bool? IsUpdateAvailable,
    string? ReasonCode,
    string? Reason,
    WintainiumApplicationReleaseModel? SelectedRelease,
    bool IsDeterministic);
