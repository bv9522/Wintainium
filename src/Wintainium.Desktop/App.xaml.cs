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
    private static readonly Dictionary<WindowId, ResourceDictionary> WindowVisualStyleResources = new();

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
            ApplyVisualStylePreference();
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
        window.Closed += (_, _) =>
        {
            ActiveWindows.Remove(windowId);
            WindowVisualStyleResources.Remove(windowId);
        };
        ApplyThemeToWindow(window);
        ApplyVisualStyleToWindow(window);
    }

    internal static void ApplyVisualStylePreference()
    {
        // Keep the visual-style dictionary at each window's root. WinUI reliably
        // invalidates ThemeResource consumers in a FrameworkElement subtree when
        // that subtree's own resource dictionary changes, whereas replacing an
        // Application-level merged dictionary does not reliably refresh an
        // already-materialized visual tree.
        foreach (var window in ActiveWindows.Values.ToArray())
        {
            ApplyVisualStyleToWindow(window);
        }
    }

    private static void ApplyVisualStyleToWindow(Window window)
    {
        if (window.Content is not FrameworkElement content)
        {
            return;
        }

        var windowId = window.AppWindow.Id;

        if (WindowVisualStyleResources.TryGetValue(windowId, out var existing))
        {
            content.Resources.MergedDictionaries.Remove(existing);
            WindowVisualStyleResources.Remove(windowId);
        }

        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            return;
        }

        var visualStyle = new ResourceDictionary
        {
            Source = new Uri("ms-appx:///Themes/Y2K.xaml")
        };

        content.Resources.MergedDictionaries.Add(visualStyle);
        WindowVisualStyleResources[windowId] = visualStyle;
    }

    internal static void ApplyThemePreference()
    {
        foreach (var window in ActiveWindows.Values.ToArray())
        {
            ApplyThemeToWindow(window);
        }
    }

    internal static void ApplyThemeToElement(FrameworkElement element)
    {
        ArgumentNullException.ThrowIfNull(element);

        var preference = Settings.Current.Theme;
        element.RequestedTheme = preference switch
        {
            WintainiumThemePreference.Light => ElementTheme.Light,
            WintainiumThemePreference.Dark => ElementTheme.Dark,
            _ => GetSystemElementTheme()
        };
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
