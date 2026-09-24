namespace Wintainium.Desktop.Models;

/// <summary>
/// Presentation model composed from authoritative Core observations.
/// Manifest identity and metadata remain distinct from InstalledState.
/// InstallationState and InstalledVersion are presentation projections of InstalledState.
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
    DateTimeOffset? LastUpdated,
    WintainiumUpdateStatus UpdateStatus,
    string? SourceProviderId,
    string? ManifestPath = null,
    WintainiumInstalledStateObservation? InstalledState = null);

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