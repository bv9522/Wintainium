using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml.Media;
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
        RefreshThemeResources(window);

        if (window.Content is FrameworkElement content)
        {
            void ApplyVisualStyleAfterLoaded(object sender, RoutedEventArgs args)
            {
                content.Loaded -= ApplyVisualStyleAfterLoaded;
                ApplyVisualStyleToWindow(window);
                RefreshThemeResources(window);
            }

            content.Loaded += ApplyVisualStyleAfterLoaded;
        }
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
            ClearY2KTextColor(content);

            ApplyWindowChromeForCurrentVisualStyle(window);
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
        ApplyY2KTextColor(content);

        ApplyWindowChromeForCurrentVisualStyle(window);
    }

    private static void ApplyWindowChromeForCurrentVisualStyle(Window window)
    {
        if (window.Content is not FrameworkElement content)
        {
            return;
        }

        if (window is MainWindow mainWindow)
        {
            mainWindow.ApplyWindowChromeForCurrentVisualStyle();
            return;
        }

        var titleBar = content.FindName("Y2KTitleBar") as Grid;
        var titleText = content.FindName("Y2KTitleBarText") as TextBlock;
        if (titleBar is null || titleText is null)
        {
            return;
        }

        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K ||
            !AppWindowTitleBar.IsCustomizationSupported())
        {
            titleBar.Visibility = Visibility.Collapsed;
            window.SetTitleBar(null);
            window.ExtendsContentIntoTitleBar = false;
            window.AppWindow.TitleBar.ResetToDefault();
            return;
        }

        var title = window switch
        {
            SettingsWindow => "Wintainium Settings",
            ApplicationDetailsWindow => window.Title,
            _ => window.Title
        };

        titleText.Text = title;
        titleText.FontFamily = new FontFamily("ms-appx:///Cyberwave2000-Regular.otf#Cyberwave 2000");
        titleText.Foreground = new SolidColorBrush(ColorHelper.FromArgb(255, 0x76, 0x5C, 0xFF));
        titleBar.Visibility = Visibility.Visible;
        window.ExtendsContentIntoTitleBar = true;
        window.SetTitleBar(titleBar);

        var nativeTitleBar = window.AppWindow.TitleBar;
        var violet = ColorHelper.FromArgb(255, 0x76, 0x5C, 0xFF);
        var violetHover = ColorHelper.FromArgb(48, 0x76, 0x5C, 0xFF);
        var violetPressed = ColorHelper.FromArgb(80, 0x76, 0x5C, 0xFF);
        nativeTitleBar.ButtonBackgroundColor = Colors.Transparent;
        nativeTitleBar.ButtonForegroundColor = violet;
        nativeTitleBar.ButtonHoverBackgroundColor = violetHover;
        nativeTitleBar.ButtonHoverForegroundColor = violet;
        nativeTitleBar.ButtonPressedBackgroundColor = violetPressed;
        nativeTitleBar.ButtonPressedForegroundColor = violet;
        nativeTitleBar.ButtonInactiveBackgroundColor = Colors.Transparent;
        nativeTitleBar.ButtonInactiveForegroundColor = violet;
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

        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            ClearY2KTextColor(element);
            return;
        }

        // ContentDialogs and other transient elements are not tracked as windows,
        // so they do not receive the window-level Y2K resource dictionaries.
        // Give them the same resource treatment locally.
        var visualStyle = new ResourceDictionary
        {
            Source = new Uri("ms-appx:///Themes/Y2K.xaml")
        };

        element.Resources.MergedDictionaries.Add(visualStyle);

        var themeKey = Settings.Current.Theme switch
        {
            WintainiumThemePreference.Dark => "Dark",
            _ => "Light"
        };

        if (visualStyle.ThemeDictionaries.TryGetValue(themeKey, out var selectedTheme)
            && selectedTheme is ResourceDictionary selectedThemeDictionary)
        {
            var activeTheme = new ResourceDictionary();
            foreach (var key in selectedThemeDictionary.Keys)
            {
                activeTheme[key] = selectedThemeDictionary[key];
            }

            element.Resources.MergedDictionaries.Add(activeTheme);
        }

        ApplyY2KTextColor(element);

        if (element is ContentDialog dialog)
        {
            ApplyY2KContentDialogPresentation(dialog);
            dialog.Loaded -= Y2KContentDialog_Loaded;
            dialog.Loaded += Y2KContentDialog_Loaded;
        }
    }

    private static void Y2KContentDialog_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is ContentDialog dialog && Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K)
        {
            ApplyY2KContentDialogPresentation(dialog);
        }
    }

    private static void ApplyY2KContentDialogPresentation(ContentDialog dialog)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            return;
        }

        if (dialog.Resources.TryGetValue("WintainiumY2KButtonStyle", out var buttonStyle)
            && buttonStyle is Style y2kButtonStyle)
        {
            dialog.PrimaryButtonStyle = y2kButtonStyle;
            dialog.SecondaryButtonStyle = y2kButtonStyle;
            dialog.CloseButtonStyle = y2kButtonStyle;
        }

        var violet = new SolidColorBrush(ColorHelper.FromArgb(255, 0x76, 0x5C, 0xFF));
        var cyberwave = new FontFamily("ms-appx:///Cyberwave2000-Regular.otf#Cyberwave 2000");
        ApplyY2KContentDialogTypography(dialog, violet, cyberwave);
    }

    private static void ApplyY2KContentDialogTypography(FrameworkElement element, Brush violet, FontFamily cyberwave)
    {
        switch (element)
        {
            case TextBlock textBlock:
                textBlock.Foreground = violet;
                textBlock.FontFamily = cyberwave;
                break;
            case Control control:
                control.Foreground = violet;
                control.FontFamily = cyberwave;
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyY2KContentDialogTypography(child, violet, cyberwave);
            }
        }
    }

    private static void ClearY2KTextColor(FrameworkElement root)
    {
        ClearY2KTextColorCore(root);
    }

    private static void ClearY2KTextColorCore(FrameworkElement element)
    {
        switch (element)
        {
            case TextBlock textBlock:
                textBlock.ClearValue(TextBlock.ForegroundProperty);
                break;
            case Control control:
                control.ClearValue(Control.ForegroundProperty);
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ClearY2KTextColorCore(child);
            }
        }
    }

    private static void ApplyY2KTextColor(FrameworkElement root)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            return;
        }

        if (Application.Current.Resources.TryGetValue("WintainiumY2KTextBrush", out var resource)
            && resource is Brush brush)
        {
            ApplyY2KTextColor(root, brush);
        }
    }

    private static void ApplyY2KTextColor(FrameworkElement element, Brush brush)
    {
        switch (element)
        {
            case TextBlock textBlock:
                textBlock.Foreground = brush;
                break;
            case Control control:
                control.Foreground = brush;
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyY2KTextColor(child, brush);
            }
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
