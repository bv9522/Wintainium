using System.Collections.Concurrent;

namespace Wintainium.Desktop.Models;

internal static class WintainiumDesktopDiagnosticsStore
{
    private static readonly ConcurrentDictionary<string, WintainiumApplicationRefreshResult> RefreshResults =
        new(StringComparer.OrdinalIgnoreCase);
    private static readonly ConcurrentDictionary<string, string> SourceResolutionReports =
        new(StringComparer.OrdinalIgnoreCase);
    private static readonly ConcurrentDictionary<string, WintainiumApplicationUpdateResult> UpdateResults =
        new(StringComparer.OrdinalIgnoreCase);
    private static readonly ConcurrentDictionary<string, WintainiumApplicationInstallResult> InstallResults =
        new(StringComparer.OrdinalIgnoreCase);

    public static void SetUpdateResult(WintainiumApplicationUpdateResult result) =>
        SetOperationResult(UpdateResults, result.ApplicationId, result);

    public static WintainiumApplicationUpdateResult? GetUpdateResult(string applicationId) =>
        GetOperationResult(UpdateResults, applicationId);

    public static void SetInstallResult(WintainiumApplicationInstallResult result) =>
        SetOperationResult(InstallResults, result.ApplicationId, result);

    public static WintainiumApplicationInstallResult? GetInstallResult(string applicationId) =>
        GetOperationResult(InstallResults, applicationId);

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

    private static void SetOperationResult<T>(
        ConcurrentDictionary<string, T> store,
        string? applicationId,
        T result)
    {
        ArgumentNullException.ThrowIfNull(result);
        if (!string.IsNullOrWhiteSpace(applicationId))
            store[applicationId] = result;
    }

    private static T? GetOperationResult<T>(
        ConcurrentDictionary<string, T> store,
        string applicationId)
        where T : class =>
        string.IsNullOrWhiteSpace(applicationId) ? null :
            store.TryGetValue(applicationId, out var result) ? result : null;
}
