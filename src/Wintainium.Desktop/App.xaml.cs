using Microsoft.UI;
using Microsoft.UI.Xaml;
using Windows.UI.ViewManagement;
using Wintainium.Desktop.Settings;

namespace Wintainium.Desktop;

public partial class App : Application
{
    private Window? _window;
    private WintainiumDesktopServices? _services;
    private readonly UISettings _uiSettings;

    internal static Dictionary<WindowId, Window> ActiveWindows { get; } = new();

    internal static WintainiumDesktopSettingsService Settings { get; } = new();

    internal WintainiumDesktopServices Services =>
        _services ??= new WintainiumDesktopServices();

    public App()
    {
        DispatcherShutdownMode = DispatcherShutdownMode.OnExplicitShutdown;
        InitializeComponent();

        _uiSettings = new UISettings();
        _uiSettings.ColorValuesChanged += SystemColors_Changed;
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        if (_window is null)
        {
            _window = new MainWindow();
            TrackWindow(_window);
            _window.Closed += MainWindow_Closed;
            _window.Activate();
        }
        else
        {
            _window.Activate();
        }
    }

    internal static void TrackWindow(Window window)
    {
        ArgumentNullException.ThrowIfNull(window);

        var windowId = window.AppWindow.Id;
        ActiveWindows[windowId] = window;
        window.Closed += (_, _) => ActiveWindows.Remove(windowId);
        ApplyThemeToWindow(window);
    }

    internal static void ApplyThemePreference()
    {
        foreach (var window in ActiveWindows.Values.ToArray())
        {
            ApplyThemeToWindow(window);
        }
    }

    internal static void ApplyThemeToWindow(Window window)
    {
        if (window.Content is not FrameworkElement content)
        {
            return;
        }

        var preference = Settings.Current.Theme;
        var theme = preference switch
        {
            WintainiumThemePreference.Light => ElementTheme.Light,
            WintainiumThemePreference.Dark => ElementTheme.Dark,
            _ => GetSystemElementTheme()
        };

        content.RequestedTheme = theme;
    }

    private static ElementTheme GetSystemElementTheme()
    {
        var color = new UISettings().GetColorValue(UIColorType.Foreground);
        var luminance = (0.299 * color.R) + (0.587 * color.G) + (0.114 * color.B);
        return luminance >= 128 ? ElementTheme.Dark : ElementTheme.Light;
    }

    private static void SystemColors_Changed(UISettings sender, object args)
    {
        if (Settings.Current.Theme != WintainiumThemePreference.System)
        {
            return;
        }

        foreach (var window in ActiveWindows.Values.ToArray())
        {
            if (window.Content is FrameworkElement content)
            {
                content.DispatcherQueue.TryEnqueue(() => ApplyThemeToWindow(window));
            }
        }
    }

    private async void MainWindow_Closed(object sender, WindowEventArgs args)
    {
        if (!ReferenceEquals(sender, _window))
        {
            return;
        }

        _window = null;

        if (_services is not null)
        {
            await _services.DisposeAsync();
            _services = null;
        }

        Exit();
    }
}
