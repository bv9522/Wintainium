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
    string? AvailableVersion,
    DateTimeOffset? LastUpdated,
    WintainiumUpdateStatus UpdateStatus,
    string? SourceProviderId,
    string? ManifestPath = null,
    WintainiumInstalledStateObservation? InstalledState = null)
{
    public string InstallationStateText => InstallationState switch
    {
        WintainiumInstallationState.Installed => "Installed",
        WintainiumInstallationState.NotInstalled => "Not installed",
        _ => "Unknown"
    };

    public string UpdateStatusText => UpdateStatus switch
    {
        WintainiumUpdateStatus.UpdateAvailable => "Update available",
        WintainiumUpdateStatus.UpToDate => "Up to date",
        _ => "Unknown"
    };

    public string InstalledVersionText => InstalledVersion ?? "Not installed";

    public string AvailableVersionText => AvailableVersion ?? "—";
}

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