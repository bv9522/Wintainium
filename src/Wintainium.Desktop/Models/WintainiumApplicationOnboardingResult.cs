namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationOnboardingResult(
    string OperationId,
    bool IsSuccessful,
    string? Status,
    WintainiumApplicationModel? Application,
    string? ManifestPath,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    string? SourceResolutionStatus,
    IReadOnlyList<WintainiumOperationDiagnostic> LogEvents,
    WintainiumOperationState OperationState = WintainiumOperationState.NotStarted);
