namespace Wintainium.Desktop.Models;

internal static class WintainiumDesktopDiagnosticsStore
{
    public static WintainiumApplicationUpdateResult? LastUpdateResult { get; private set; }
    public static WintainiumApplicationInstallResult? LastInstallResult { get; private set; }

    public static void SetUpdateResult(WintainiumApplicationUpdateResult result) => LastUpdateResult = result;

    public static void SetInstallResult(WintainiumApplicationInstallResult result) => LastInstallResult = result;
}