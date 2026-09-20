namespace Wintainium.Desktop.Models;

/// <summary>
/// Applies presentation-only sorting and filtering to an application collection.
/// Unknown Core-owned states remain unknown and are never reclassified.
/// </summary>
internal static class WintainiumApplicationCollectionQuery
{
    public static IReadOnlyList<WintainiumApplicationModel> Apply(
        IEnumerable<WintainiumApplicationModel> applications,
        WintainiumApplicationQuery query)
    {
        ArgumentNullException.ThrowIfNull(applications);
        ArgumentNullException.ThrowIfNull(query);

        IEnumerable<WintainiumApplicationModel> filtered = query.Filter switch
        {
            WintainiumApplicationFilter.All => applications,
            WintainiumApplicationFilter.UpdateAvailable =>
                applications.Where(static app => app.UpdateStatus == WintainiumUpdateStatus.UpdateAvailable),
            WintainiumApplicationFilter.UpToDate =>
                applications.Where(static app => app.UpdateStatus == WintainiumUpdateStatus.UpToDate),
            WintainiumApplicationFilter.Installed =>
                applications.Where(static app => app.InstallationState == WintainiumInstallationState.Installed),
            WintainiumApplicationFilter.NotInstalled =>
                applications.Where(static app => app.InstallationState == WintainiumInstallationState.NotInstalled),
            _ => throw new ArgumentOutOfRangeException(nameof(query), query.Filter, "Unknown application filter.")
        };

        IOrderedEnumerable<WintainiumApplicationModel> ordered = query.Sort switch
        {
            WintainiumApplicationSort.NameAscending =>
                filtered.OrderBy(static app => app.Name, StringComparer.CurrentCultureIgnoreCase),
            WintainiumApplicationSort.NameDescending =>
                filtered.OrderByDescending(static app => app.Name, StringComparer.CurrentCultureIgnoreCase),
            WintainiumApplicationSort.UpdateStatus =>
                filtered.OrderBy(static app => UpdateStatusSortKey(app.UpdateStatus)),
            WintainiumApplicationSort.InstallationStatus =>
                filtered.OrderBy(static app => InstallationStatusSortKey(app.InstallationState)),
            WintainiumApplicationSort.Source =>
                filtered.OrderBy(static app => app.SourceProviderId ?? string.Empty, StringComparer.CurrentCultureIgnoreCase),
            _ => throw new ArgumentOutOfRangeException(nameof(query), query.Sort, "Unknown application sort.")
        };

        return ordered
            .ThenBy(static app => app.Name, StringComparer.CurrentCultureIgnoreCase)
            .ThenBy(static app => app.ApplicationId, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static int UpdateStatusSortKey(WintainiumUpdateStatus status) =>
        status switch
        {
            WintainiumUpdateStatus.Unknown => 0,
            WintainiumUpdateStatus.UpdateAvailable => 1,
            WintainiumUpdateStatus.UpToDate => 2,
            _ => throw new ArgumentOutOfRangeException(nameof(status), status, "Unknown update status.")
        };

    private static int InstallationStatusSortKey(WintainiumInstallationState state) =>
        state switch
        {
            WintainiumInstallationState.Unknown => 0,
            WintainiumInstallationState.Installed => 1,
            WintainiumInstallationState.NotInstalled => 2,
            _ => throw new ArgumentOutOfRangeException(nameof(state), state, "Unknown installation state.")
        };
}
