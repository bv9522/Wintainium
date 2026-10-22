using System.Collections.Concurrent;

namespace Wintainium.Desktop.Models;

internal static class WintainiumDesktopDiagnosticsStore
{
    private static readonly ConcurrentDictionary<string, WintainiumApplicationRefreshResult> RefreshResults =
        new(StringComparer.OrdinalIgnoreCase);
    private static readonly ConcurrentDictionary<string, string> SourceResolutionReports =
        new(StringComparer.OrdinalIgnoreCase);

    public static WintainiumApplicationUpdateResult? LastUpdateResult { get; private set; }
    public static WintainiumApplicationInstallResult? LastInstallResult { get; private set; }

    public static void SetUpdateResult(WintainiumApplicationUpdateResult result) => LastUpdateResult = result;

    public static void SetInstallResult(WintainiumApplicationInstallResult result) => LastInstallResult = result;

    public static void SetRefreshResult(string applicationId, WintainiumApplicationRefreshResult result)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(applicationId);
        ArgumentNullException.ThrowIfNull(result);
        RefreshResults[applicationId] = result;
    }

    public static WintainiumApplicationRefreshResult? GetRefreshResult(string applicationId) =>
        string.IsNullOrWhiteSpace(applicationId) ? null :
            RefreshResults.TryGetValue(applicationId, out var result) ? result : null;

    public static void SetSourceResolutionReport(string applicationId, string report)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(applicationId);
        ArgumentException.ThrowIfNullOrWhiteSpace(report);
        SourceResolutionReports[applicationId] = report;
    }

    public static string? GetSourceResolutionReport(string applicationId) =>
        string.IsNullOrWhiteSpace(applicationId) ? null :
            SourceResolutionReports.TryGetValue(applicationId, out var report) ? report : null;
}
