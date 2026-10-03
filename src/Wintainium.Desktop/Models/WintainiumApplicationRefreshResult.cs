namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationRefreshResult(
    WintainiumApplicationModel Application,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings);
