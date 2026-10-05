namespace Wintainium.Desktop.Settings;

internal enum WintainiumThemePreference
{
    System,
    Light,
    Dark
}

internal enum WintainiumVisualStyle
{
    Windows11,
    Y2K,
    FrutigerAero
}

internal enum WintainiumUpdateCheckFrequency
{
    Daily,
    Weekly,
    EveryTwoWeeks,
    Monthly
}

internal sealed record WintainiumDesktopSettings(
    WintainiumThemePreference Theme,
    WintainiumVisualStyle VisualStyle,
    bool LaunchAtSignIn,
    bool ConfirmBeforeInstallOrUpdate,
    bool ConfirmBeforeRemove,
    bool CloseAfterOperation,
    bool ShowOperationNotifications,
    bool AutomaticallyCheckForUpdates,
    WintainiumUpdateCheckFrequency UpdateCheckFrequency,
    bool AutomaticallyInstallUpdates,
    bool NotifyWhenUpdatesAvailable,
    bool NotifyWhenUpdatesInstalled,
    bool NotifyWhenUpdateFails)
{
    public static WintainiumDesktopSettings Defaults { get; } = new(
        WintainiumThemePreference.System,
        WintainiumVisualStyle.Windows11,
        false,
        true,
        true,
        false,
        true,
        false,
        WintainiumUpdateCheckFrequency.Weekly,
        false,
        true,
        true,
        true);
}
