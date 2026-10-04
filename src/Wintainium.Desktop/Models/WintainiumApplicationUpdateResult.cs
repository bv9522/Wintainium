namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationUpdateResult(
    string? OperationId,
    bool IsSuccessful,
    bool WasCancelled,
    string? Status,
    string? ApplicationId,
    IReadOnlyList<WintainiumApplicationUpdateStageModel> Stages,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    IReadOnlyList<WintainiumOperationDiagnostic> LogEvents,
    IReadOnlyList<WintainiumOperationDiagnostic> TroubleshootingDiagnostics,
    WintainiumOperationDiagnostic? Error,
    WintainiumOperationState OperationState);

internal sealed record WintainiumApplicationUpdateStageModel(
    int Sequence,
    string? Name,
    string? Status,
    string? ReasonCode,
    string? Reason,
    bool IsSuccessful,
    bool WasCancelled,
    WintainiumOperationDiagnostic? Error);