namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationInstalledStateResult(
    string OperationId,
    string ApplicationId,
    bool IsSuccessful,
    string? Status,
    WintainiumInstalledStateObservation? State,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    WintainiumOperationState OperationState = WintainiumOperationState.NotStarted);

internal sealed record WintainiumInstalledStateObservation(
    string ApplicationId,
    WintainiumInstallationState InstallationState,
    string? Version,
    string? VersionSource,
    string? Architecture,
    string? Channel,
    string? InstallationLocation);
