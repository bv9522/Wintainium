namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationInstallResult(
    string? OperationId,
    bool IsSuccessful,
    bool WasCancelled,
    string? Status,
    string? ApplicationId,
    IReadOnlyList<WintainiumApplicationInstallStageModel> Stages,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    IReadOnlyList<WintainiumOperationDiagnostic> LogEvents,
    WintainiumOperationDiagnostic? Error,
    WintainiumOperationState OperationState);

internal sealed record WintainiumApplicationInstallStageModel(
    int Sequence,
    string? Name,
    string? Status,
    bool IsSuccessful,
    bool WasCancelled,
    WintainiumOperationDiagnostic? Error);
