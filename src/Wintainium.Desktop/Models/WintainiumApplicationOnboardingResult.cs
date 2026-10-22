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
    IReadOnlyList<WintainiumApplicationOnboardingStage> Stages,
    WintainiumOperationState OperationState = WintainiumOperationState.NotStarted);

internal sealed record WintainiumApplicationOnboardingStage(
    int Sequence,
    string Name,
    string? Status,
    bool IsSuccessful,
    string? ReasonCode,
    string? Reason);
