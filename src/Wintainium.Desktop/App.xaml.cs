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
    private static readonly Dictionary<WindowId, (ResourceDictionary VisualStyle, ResourceDictionary ActiveTheme)> WindowVisualStyleResources = new();

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
        foreach (var window in ActiveWindows.Values.ToArray())
        {
            ApplyVisualStyleToWindow(window);
            RefreshThemeResources(window);
        }
    }

    private static void RefreshThemeResources(Window window)
    {
        if (window.Content is not FrameworkElement content)
        {
            return;
        }

        var effectiveTheme = Settings.Current.Theme switch
        {
            WintainiumThemePreference.Light => ElementTheme.Light,
            WintainiumThemePreference.Dark => ElementTheme.Dark,
            _ => GetSystemElementTheme()
        };

        // ThemeResource is explicitly re-evaluated by WinUI when a FrameworkElement
        // undergoes a real theme transition. Re-applying the same theme is not
        // sufficient, so briefly move to the opposite theme and immediately return
        // to the user's effective theme. The final visual state is unchanged while
        // the existing visual tree is forced to resolve the newly selected style
        // resources.
        var alternateTheme = effectiveTheme == ElementTheme.Light
            ? ElementTheme.Dark
            : ElementTheme.Light;

        content.RequestedTheme = alternateTheme;

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K)
        {
            // The Y2K dictionary is attached at runtime. Defer the return to the
            // effective theme so WinUI completes a real theme-resource pass after
            // the new dictionary is part of the live resource tree.
            content.DispatcherQueue.TryEnqueue(() => content.RequestedTheme = effectiveTheme);
        }
        else
        {
            content.RequestedTheme = effectiveTheme;
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
            content.Resources.MergedDictionaries.Remove(existing.ActiveTheme);
            content.Resources.MergedDictionaries.Remove(existing.VisualStyle);
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

        // WinUI's built-in ThemeResource lookup does not reliably re-resolve
        // ThemeDictionaries that are introduced by a runtime merge. Flatten the
        // selected Y2K theme dictionary into a normal runtime dictionary so the
        // Y2K resources become an explicit, highest-precedence window resource.
        var themeKey = Settings.Current.Theme switch
        {
            WintainiumThemePreference.Dark => "Dark",
            _ => "Light"
        };

        var activeTheme = new ResourceDictionary();
        if (visualStyle.ThemeDictionaries.TryGetValue(themeKey, out var selectedTheme)
            && selectedTheme is ResourceDictionary selectedThemeDictionary)
        {
            foreach (var key in selectedThemeDictionary.Keys)
            {
                activeTheme[key] = selectedThemeDictionary[key];
            }
        }

        content.Resources.MergedDictionaries.Add(activeTheme);
        WindowVisualStyleResources[windowId] = (visualStyle, activeTheme);
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
