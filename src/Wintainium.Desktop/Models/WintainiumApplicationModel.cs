namespace Wintainium.Desktop.Models;

/// <summary>
/// Presentation model for one tracked Wintainium application.
/// </summary>
internal sealed record WintainiumApplicationModel(
    string ApplicationId,
    string Name,
    string? Description,
    string? Homepage,
    string? Publisher,
    string? IconUri,
    WintainiumInstallationState InstallationState,
    string? InstalledVersion,
    string? LastUpdatedDisplay,
    WintainiumUpdateStatus UpdateStatus,
    string? SourceDisplayName);

internal enum WintainiumInstallationState
{
    Installed,
    NotInstalled,
    Unknown
}

internal enum WintainiumUpdateStatus
{
    Unknown,
    UpdateAvailable,
    UpToDate
}