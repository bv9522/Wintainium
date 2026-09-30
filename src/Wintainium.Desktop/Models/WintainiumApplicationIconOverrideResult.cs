namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationIconOverrideResult(
    string OperationId,
    bool IsSuccessful,
    string? Status,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings);
