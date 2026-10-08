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
            ApplyThemeToWindow(window);
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

        var alternateTheme = effectiveTheme == ElementTheme.Light
            ? ElementTheme.Dark
            : ElementTheme.Light;

        content.RequestedTheme = alternateTheme;

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K)
        {
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

            if (window is MainWindow
                && content is Panel clearPanel)
            {
                clearPanel.ClearValue(Panel.BackgroundProperty);
            }

            ApplyWindowChromeForCurrentVisualStyle(window);
            return;
        }

        var visualStyle = new ResourceDictionary
        {
            Source = new Uri("ms-appx:///Themes/Y2K.xaml")
        };

        content.Resources.MergedDictionaries.Add(visualStyle);

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

        if (window is MainWindow
            && content is Panel backgroundPanel
            && activeTheme.TryGetValue("ApplicationPageBackgroundThemeBrush", out var background)
            && background is Brush backgroundBrush)
        {
            backgroundPanel.Background = backgroundBrush;
        }

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
        titleText.FontFamily = GetY2KDisplayFont();
        titleText.Foreground = GetY2KTextBrush();
        if (WindowVisualStyleResources.TryGetValue(window.AppWindow.Id, out var resources)
            && resources.ActiveTheme.TryGetValue("WintainiumY2KTitleBarBrush", out var titleBarBrush)
            && titleBarBrush is Brush titleBarBackground)
        {
            titleBar.Background = titleBarBackground;
        }
        titleBar.Visibility = Visibility.Visible;
        window.ExtendsContentIntoTitleBar = true;
        window.SetTitleBar(titleBar);

        var nativeTitleBar = window.AppWindow.TitleBar;
        var textColor = Settings.Current.Theme == WintainiumThemePreference.Dark
            ? ColorHelper.FromArgb(255, 0x39, 0xFF, 0x9A)
            : ColorHelper.FromArgb(255, 0x76, 0x5C, 0xFF);
        var textHover = ColorHelper.FromArgb(48, textColor.R, textColor.G, textColor.B);
        var textPressed = ColorHelper.FromArgb(80, textColor.R, textColor.G, textColor.B);
        nativeTitleBar.ButtonBackgroundColor = Colors.Transparent;
        nativeTitleBar.ButtonForegroundColor = textColor;
        nativeTitleBar.ButtonHoverBackgroundColor = textHover;
        nativeTitleBar.ButtonHoverForegroundColor = textColor;
        nativeTitleBar.ButtonPressedBackgroundColor = textPressed;
        nativeTitleBar.ButtonPressedForegroundColor = textColor;
        nativeTitleBar.ButtonInactiveBackgroundColor = Colors.Transparent;
        nativeTitleBar.ButtonInactiveForegroundColor = textColor;
    }

    internal static void ApplyThemePreference()
    {
        foreach (var window in ActiveWindows.Values.ToArray())
        {
            ApplyThemeToWindow(window);
            ApplyVisualStyleToWindow(window);
            RefreshThemeResources(window);
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

        var textBrush = GetY2KTextBrush();
        var displayFont = GetY2KDisplayFont();
        ApplyY2KContentDialogTypography(dialog, textBrush, displayFont, dialog.CloseButtonStyle);
    }

    private static void ApplyY2KContentDialogTypography(
        FrameworkElement element,
        Brush textBrush,
        FontFamily displayFont,
        Style? buttonStyle)
    {
        switch (element)
        {
            case TextBlock textBlock:
                textBlock.Foreground = textBrush;
                textBlock.FontFamily = displayFont;
                break;
            case Button button:
                if (buttonStyle is not null)
                {
                    button.Style = buttonStyle;
                }

                button.Foreground = textBrush;
                button.FontFamily = displayFont;
                break;
            case Control control:
                control.Foreground = textBrush;
                control.FontFamily = displayFont;
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyY2KContentDialogTypography(child, textBrush, displayFont, buttonStyle);
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
                if (textBlock.FontFamily?.Source is string fontSource &&
                    (fontSource.Equals("Consolas", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("Cyberwave2000-Regular.otf", StringComparison.OrdinalIgnoreCase)))
                {
                    textBlock.ClearValue(TextBlock.FontFamilyProperty);
                }
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

    internal static void ApplyY2KTextColor(FrameworkElement root)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            return;
        }

        ApplyY2KTextColor(root, GetY2KTextBrush(), GetY2KDisplayFont());
    }

    private static void ApplyY2KTextColor(FrameworkElement element, Brush brush, FontFamily font)
    {
        switch (element)
        {
            case TextBlock textBlock:
                textBlock.Foreground = brush;
                if (textBlock.FontFamily?.Source is not string fontSource ||
                    !fontSource.Contains("Segoe MDL2 Assets", StringComparison.OrdinalIgnoreCase))
                {
                    textBlock.FontFamily = font;
                }
                break;
            case Control control:
                control.Foreground = brush;
                control.FontFamily = font;
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyY2KTextColor(child, brush, font);
            }
        }
    }

    internal static Brush GetY2KTextBrush()
    {
        if (Settings.Current.Theme == WintainiumThemePreference.Dark)
        {
            return new SolidColorBrush(ColorHelper.FromArgb(255, 0x39, 0xFF, 0x9A));
        }

        if (Application.Current.Resources.TryGetValue("WintainiumY2KTextBrush", out var resource)
            && resource is Brush brush)
        {
            return brush;
        }

        return new SolidColorBrush(ColorHelper.FromArgb(255, 0x76, 0x5C, 0xFF));
    }

    internal static FontFamily GetY2KDisplayFont()
    {
        return Settings.Current.Theme == WintainiumThemePreference.Dark
            ? new FontFamily("Consolas")
            : new FontFamily("ms-appx:///Cyberwave2000-Regular.otf#Cyberwave 2000");
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
