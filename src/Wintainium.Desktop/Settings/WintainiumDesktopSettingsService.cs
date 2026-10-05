using System.Text.Json;

namespace Wintainium.Desktop.Settings;

internal sealed class WintainiumDesktopSettingsService
{
    private readonly string _settingsPath;
    private WintainiumDesktopSettings _current;

    public WintainiumDesktopSettingsService()
    {
        _settingsPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Wintainium",
            "Settings",
            "desktop-settings.json");

        _current = Load();
    }

    public WintainiumDesktopSettings Current => _current;

    public void SetTheme(WintainiumThemePreference theme) =>
        Save(_current with { Theme = theme });

    public void SetVisualStyle(WintainiumVisualStyle visualStyle) =>
        Save(_current with { VisualStyle = visualStyle });

    public void SetLaunchAtSignIn(bool value) =>
        Save(_current with { LaunchAtSignIn = value });

    public void SetConfirmBeforeInstallOrUpdate(bool value) =>
        Save(_current with { ConfirmBeforeInstallOrUpdate = value });

    public void SetConfirmBeforeRemove(bool value) =>
        Save(_current with { ConfirmBeforeRemove = value });

    public void SetCloseAfterOperation(bool value) =>
        Save(_current with { CloseAfterOperation = value });

    public void SetShowOperationNotifications(bool value) =>
        Save(_current with { ShowOperationNotifications = value });

    public void SetAutomaticallyCheckForUpdates(bool value) =>
        Save(_current with { AutomaticallyCheckForUpdates = value });

    public void SetUpdateCheckFrequency(WintainiumUpdateCheckFrequency value) =>
        Save(_current with { UpdateCheckFrequency = value });

    public void SetAutomaticallyInstallUpdates(bool value) =>
        Save(_current with { AutomaticallyInstallUpdates = value });

    public void SetNotifyWhenUpdatesAvailable(bool value) =>
        Save(_current with { NotifyWhenUpdatesAvailable = value });

    public void SetNotifyWhenUpdatesInstalled(bool value) =>
        Save(_current with { NotifyWhenUpdatesInstalled = value });

    public void SetNotifyWhenUpdateFails(bool value) =>
        Save(_current with { NotifyWhenUpdateFails = value });

    private void Save(WintainiumDesktopSettings settings)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_settingsPath)!);
        var json = JsonSerializer.Serialize(settings, new JsonSerializerOptions
        {
            WriteIndented = true
        });
        File.WriteAllText(_settingsPath, json);
        _current = settings;
    }

    private WintainiumDesktopSettings Load()
    {
        try
        {
            if (!File.Exists(_settingsPath))
            {
                return WintainiumDesktopSettings.Defaults;
            }

            var json = File.ReadAllText(_settingsPath);
            return JsonSerializer.Deserialize<WintainiumDesktopSettings>(json)
                ?? WintainiumDesktopSettings.Defaults;
        }
        catch
        {
            return WintainiumDesktopSettings.Defaults;
        }
    }
}
