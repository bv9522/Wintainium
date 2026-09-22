namespace Wintainium.Desktop.Settings;

internal sealed class WintainiumDesktopSettingsService
{
    private WintainiumDesktopSettings _current = new(
        WintainiumThemePreference.System,
        WintainiumVisualStyle.Windows11);

    public WintainiumDesktopSettings Current => _current;

    public void SetTheme(WintainiumThemePreference theme)
    {
        _current = _current with { Theme = theme };
    }

    public void SetVisualStyle(WintainiumVisualStyle visualStyle)
    {
        _current = _current with { VisualStyle = visualStyle };
    }
}
