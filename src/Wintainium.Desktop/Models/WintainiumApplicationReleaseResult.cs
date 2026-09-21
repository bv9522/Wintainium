namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationReleaseResult(
    string OperationId,
    bool IsSuccessful,
    string? Status,
    IReadOnlyList<WintainiumApplicationReleaseModel> Releases,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    WintainiumOperationState OperationState = WintainiumOperationState.NotStarted);