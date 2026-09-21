namespace Wintainium.Desktop.Models;

internal enum WintainiumOperationState
{
    NotStarted,
    Running,
    Completed,
    Failed,
    Cancelled
}

internal sealed record WintainiumOperationStateModel(
    string OperationId,
    WintainiumOperationState State,
    bool IsSuccessful,
    bool WasCancelled,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings);
