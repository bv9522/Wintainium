namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationRemovalResult(
    string OperationId,
    bool IsSuccessful,
    string? Status,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings);
