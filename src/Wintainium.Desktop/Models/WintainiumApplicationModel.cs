namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationModel(
    string ApplicationId,
    string Name,
    string? Description,
    string? Homepage,
    string? Publisher,
    string? IconUri,
    WintainiumInstallationState InstallationState,
    string? InstalledVersion,
    DateTimeOffset? LastUpdated,
    WintainiumUpdateStatus UpdateStatus,
    string? SourceProviderId,
    string? ManifestPath = null);

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