namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationValidationResult(
    string OperationId,
    bool IsValid,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    WintainiumOperationState OperationState = WintainiumOperationState.NotStarted);
