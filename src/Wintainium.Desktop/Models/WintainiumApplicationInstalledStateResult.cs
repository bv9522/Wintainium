namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationInstalledStateResult(
    string OperationId,
    string ApplicationId,
    bool IsSuccessful,
    string? Status,
    WintainiumInstalledStateObservation? State,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    WintainiumOperationState OperationState = WintainiumOperationState.NotStarted,
    IReadOnlyList<WintainiumOperationLogEvent>? LogEvents = null,
    WintainiumReconciliationTrace? Reconciliation = null);

internal sealed record WintainiumReconciliationTrace(
    string? Status,
    bool IsSuccessful,
    string? EvidenceSource,
    string? ObservedInstallationState,
    string? ReasonCode,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    IReadOnlyList<WintainiumOperationLogEvent> LogEvents);

internal sealed record WintainiumInstalledStateObservation(
    string ApplicationId,
    WintainiumInstallationState InstallationState,
    string? Version,
    string? VersionSource,
    string? Architecture,
    string? Channel,
    string? InstallationLocation);
