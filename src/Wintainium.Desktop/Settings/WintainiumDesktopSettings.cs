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

internal sealed record WintainiumDesktopSettings(
    WintainiumThemePreference Theme,
    WintainiumVisualStyle VisualStyle);
