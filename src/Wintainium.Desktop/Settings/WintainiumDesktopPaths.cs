namespace Wintainium.Desktop.Settings;

/// <summary>
/// Defines fixed desktop-owned paths that point into Core's authoritative stores.
/// The desktop chooses the collection root but does not implement manifest persistence.
/// </summary>
internal static class WintainiumDesktopPaths
{
    public static string ManifestRoot { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Wintainium",
        "Applications");
}
