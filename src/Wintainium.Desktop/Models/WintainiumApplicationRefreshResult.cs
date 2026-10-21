namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationRefreshResult(
    WintainiumApplicationModel Application,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    string? OperationId = null,
    IReadOnlyList<WintainiumApplicationRefreshStage>? Stages = null,
    DateTimeOffset? CapturedAtUtc = null);

internal sealed record WintainiumApplicationRefreshStage(
    string Name,
    string? OperationId,
    string Status,
    string? ReasonCode,
    WintainiumInstallationState? StateBefore,
    WintainiumInstallationState? StateAfter,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    IReadOnlyList<WintainiumOperationLogEvent> LogEvents);
