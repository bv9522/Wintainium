namespace Wintainium.Desktop.Models;

internal enum WintainiumApplicationSort
{
    NameAscending,
    NameDescending,
    UpdateStatus,
    InstallationStatus,
    Source
}

internal enum WintainiumApplicationFilter
{
    All,
    UpdateAvailable,
    UpToDate,
    Installed,
    NotInstalled
}

/// <summary>
/// Describes a presentation query over the already-loaded application collection.
/// This type contains no engine policy or update decision logic.
/// </summary>
internal sealed record WintainiumApplicationQuery(
    WintainiumApplicationSort Sort = WintainiumApplicationSort.NameAscending,
    WintainiumApplicationFilter Filter = WintainiumApplicationFilter.All);
