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
    /// <summary>
    /// User-facing name used by the desktop presentation. The canonical Name remains
    /// unchanged for identity, matching, and manifest semantics.
    /// This conservative fallback only repairs an all-lowercase single-token name;
    /// provider-supplied or user-defined display metadata can replace it later.
    /// </summary>
    public string DisplayName => GetDisplayName(Name);

    public string InstallationStateText => InstallationState switch
    {
        WintainiumInstallationState.Installed => "Installed",
        WintainiumInstallationState.NotInstalled => "Not installed",
        _ => "Unknown"
    };

    public string UpdateStatusText => UpdateStatus switch
    {
        WintainiumUpdateStatus.NotInstalled => "Not installed",
        WintainiumUpdateStatus.UpdateAvailable => "Update available",
        WintainiumUpdateStatus.UpToDate => "Up to date",
        _ => "Unknown"
    };

    private static string GetDisplayName(string name)
    {
        if (string.IsNullOrWhiteSpace(name) || name.Any(char.IsUpper))
            return name;

        var firstLetter = name.IndexOfAny("abcdefghijklmnopqrstuvwxyz".ToCharArray());
        if (firstLetter < 0)
            return name;

        return name[..firstLetter] + char.ToUpperInvariant(name[firstLetter]) + name[(firstLetter + 1)..];
    }

    public string InstalledVersionText => InstalledVersion ?? "Not installed";

    public string AvailableVersionText => AvailableVersion ?? "—";

    public string PublisherText => string.IsNullOrWhiteSpace(Publisher)
        ? "Publisher unknown"
        : Publisher;

    public string SourceProviderText => string.IsNullOrWhiteSpace(SourceProviderId)
        ? "Source unknown"
        : SourceProviderId;
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
    NotInstalled,
    UpdateAvailable,
    UpToDate
}
