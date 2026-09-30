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

        if (name[0] is < 'a' or > 'z')
            return name;

        return char.ToUpperInvariant(name[0]) + name[1..];
    }

    public string IconSourceText => IconSource switch\n    {\n        WintainiumIconSource.None => "No Icon",\n        WintainiumIconSource.WintainiumSourced => "Wintainium Sourced Icon",\n        WintainiumIconSource.Custom => "Custom Icon",\n        _ => "No Icon"\n    };\n\n    public string InstalledVersionText => InstalledVersion ?? "Not installed";

    public string AvailableVersionText => AvailableVersion ?? "—";

    public string PublisherText => string.IsNullOrWhiteSpace(Publisher)
        ? "Publisher unknown"
        : Publisher;

    public string SourceProviderText => string.IsNullOrWhiteSpace(SourceProviderId)
        ? "Source unknown"
        : SourceProviderId;
}
    
internal enum WintainiumIconSource\n{\n    None,\n    WintainiumSourced,\n    Custom\n}\n\ninternal enum WintainiumInstallationState
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
