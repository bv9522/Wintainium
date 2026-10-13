using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using Windows.Foundation;
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
                if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K)
                {
                    QueueY2KTextColorPass(content);
                }
                else if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
                    && Settings.Current.Theme == WintainiumThemePreference.Light)
                {
                    ApplyFrutigerAeroTypography(content, preserveSoftwareCardTypography: window is MainWindow);
                }
                else if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
                    && Settings.Current.Theme == WintainiumThemePreference.Dark
                    && window is not MainWindow)
                {
                    ApplyFrutigerMetroDarkAppearance(content);
                }
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
            if (window.Content is FrameworkElement content)
            {
                if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K)
                {
                    QueueY2KTextColorPass(content);
                }
                else if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
                    && Settings.Current.Theme == WintainiumThemePreference.Light)
                {
                    ApplyFrutigerAeroTypography(content, preserveSoftwareCardTypography: window is MainWindow);
                }
            }

            if (window is MainWindow mainWindow)
            {
                mainWindow.RefreshSoftwareCardTextColors();
            }

            if (window is SettingsWindow settingsWindow)
            {
                settingsWindow.RefreshAppearance();
            }
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

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K
            || (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
                && Settings.Current.Theme == WintainiumThemePreference.Light))
        {
            // Re-applying RequestedTheme forces ThemeResource brushes to refresh after
            // a runtime dictionary swap, including open Settings windows and dropdowns.
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
        var isFrutigerMetroDark = Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && Settings.Current.Theme == WintainiumThemePreference.Dark;

        if (!isFrutigerMetroDark
            && content.FindName("FrutigerMetroBackdrop") is FrameworkElement previousMetroBackdrop)
        {
            previousMetroBackdrop.Visibility = Visibility.Collapsed;
        }

        if (!isFrutigerMetroDark)
        {
            ClearFrutigerMetroDarkAppearance(content);
        }

        if (WindowVisualStyleResources.TryGetValue(windowId, out var existing))
        {
            content.Resources.MergedDictionaries.Remove(existing.ActiveTheme);
            content.Resources.MergedDictionaries.Remove(existing.VisualStyle);
            WindowVisualStyleResources.Remove(windowId);
        }

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && Settings.Current.Theme == WintainiumThemePreference.Light)
        {
            var aeroStyle = new ResourceDictionary
            {
                Source = new Uri("ms-appx:///Themes/FrutigerAero-Light.xaml")
            };
            content.Resources.MergedDictionaries.Add(aeroStyle);
            var activeAeroTheme = new ResourceDictionary();
            WindowVisualStyleResources[windowId] = (aeroStyle, activeAeroTheme);
            ApplyFrutigerAeroTypography(content, preserveSoftwareCardTypography: window is MainWindow);
            ApplyWindowChromeForCurrentVisualStyle(window);
            return;
        }

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && Settings.Current.Theme == WintainiumThemePreference.Dark)
        {
            if (content.FindName("FrutigerMetroBackdrop") is FrameworkElement metroBackdrop)
            {
                metroBackdrop.Visibility = Visibility.Visible;
            }

            // MainWindow owns its compact card surfaces and typography. Do not recursively
            // paint every Control/Border here; doing so makes the ListView a giant opaque panel.
            if (window is MainWindow mainWindow)
            {
                mainWindow.ApplyWindowChromeForCurrentVisualStyle();
                return;
            }

            ApplyFrutigerMetroDarkAppearance(content);
            ApplyWindowChromeForCurrentVisualStyle(window);
            return;
        }

        if (content.FindName("FrutigerMetroBackdrop") is FrameworkElement hiddenMetroBackdrop)
        {
            hiddenMetroBackdrop.Visibility = Visibility.Collapsed;
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

        var themeKey = Settings.Current.Theme switch
        {
            WintainiumThemePreference.Light => "Light",
            _ => "Dark"
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

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && Settings.Current.Theme == WintainiumThemePreference.Light)
        {
            ApplyFrutigerAeroTitleBar(window, titleBar, titleText);
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
        var textColor = Settings.Current.Theme != WintainiumThemePreference.Light
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

    internal static void ApplyFrutigerAeroTitleBar(Window window, Grid titleBar, TextBlock titleText)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.FrutigerAero
            || Settings.Current.Theme != WintainiumThemePreference.Light)
        {
            return;
        }

        if (!AppWindowTitleBar.IsCustomizationSupported())
        {
            titleBar.Visibility = Visibility.Collapsed;
            window.SetTitleBar(null);
            window.ExtendsContentIntoTitleBar = false;
            window.AppWindow.TitleBar.ResetToDefault();
            return;
        }

        titleText.Text = window.Title;
        titleText.FontFamily = new FontFamily("ms-appx:///Horatio%20D%20Regular.ttf#Horatio D");
        titleText.Foreground = new SolidColorBrush(ColorHelper.FromArgb(255, 0x17, 0x4F, 0x67));
        titleText.FontSize = Math.Max(titleText.FontSize, 16);
        titleBar.Background = GetFrutigerAeroTitleBarBrush();
        titleBar.Visibility = Visibility.Visible;
        window.ExtendsContentIntoTitleBar = true;
        window.SetTitleBar(titleBar);

        var nativeTitleBar = window.AppWindow.TitleBar;
        var textColor = ColorHelper.FromArgb(255, 0x17, 0x4F, 0x67);
        nativeTitleBar.BackgroundColor = Colors.Transparent;
        nativeTitleBar.ForegroundColor = textColor;
        nativeTitleBar.InactiveBackgroundColor = Colors.Transparent;
        nativeTitleBar.InactiveForegroundColor = textColor;
        nativeTitleBar.ButtonBackgroundColor = Colors.Transparent;
        nativeTitleBar.ButtonForegroundColor = textColor;
        nativeTitleBar.ButtonHoverBackgroundColor = ColorHelper.FromArgb(42, 0xFF, 0xFF, 0xFF);
        nativeTitleBar.ButtonHoverForegroundColor = textColor;
        nativeTitleBar.ButtonPressedBackgroundColor = ColorHelper.FromArgb(72, 0x5B, 0xB9, 0xD0);
        nativeTitleBar.ButtonPressedForegroundColor = textColor;
        nativeTitleBar.ButtonInactiveBackgroundColor = ColorHelper.FromArgb(18, 0xFF, 0xFF, 0xFF);
        nativeTitleBar.ButtonInactiveForegroundColor = textColor;
    }

    internal static Brush GetFrutigerAeroTitleBarBrush()
    {
        return new LinearGradientBrush
        {
            StartPoint = new Windows.Foundation.Point(0, 0),
            EndPoint = new Windows.Foundation.Point(0, 1),
            GradientStops =
            {
                new GradientStop { Color = ColorHelper.FromArgb(242, 0xF4, 0xFD, 0xFF), Offset = 0 },
                new GradientStop { Color = ColorHelper.FromArgb(218, 0xD4, 0xF5, 0xFC), Offset = 0.18 },
                new GradientStop { Color = ColorHelper.FromArgb(190, 0x8D, 0xD7, 0xEB), Offset = 0.52 },
                new GradientStop { Color = ColorHelper.FromArgb(224, 0xC8, 0xF0, 0xF8), Offset = 0.78 },
                new GradientStop { Color = ColorHelper.FromArgb(238, 0xE9, 0xFA, 0xFC), Offset = 1 }
            }
        };
    }

    private static void EnsureFrutigerMetroDialogBackdrop(ContentDialog dialog)
    {
        if (dialog.Content is not FrameworkElement currentContent
            || currentContent.Tag as string == "FrutigerMetroDialogBackdropHost")
        {
            return;
        }

        // Reuse the exact backdrop UserControl used by MainWindow so the main window
        // and these dialogs cannot drift into separate Metro artwork implementations.
        var host = new Grid
        {
            Tag = "FrutigerMetroDialogBackdropHost",
            MinWidth = 420,
            MinHeight = 250
        };
        var backdrop = new FrutigerMetroBackdrop
        {
            IsHitTestVisible = false,
            Visibility = Visibility.Visible
        };
        host.Children.Add(backdrop);
        host.Children.Add(currentContent);
        dialog.Content = host;
    }

    private static void FrutigerMetroContentDialog_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is ContentDialog dialog
            && Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && Settings.Current.Theme == WintainiumThemePreference.Dark)
        {
            // Keep dialog content in its original visual-tree parent. Reparenting
            // ContentDialog.Content from its presenter during Loaded can throw and
            // terminate the async-void command handler. Use a Metro gradient instead.
            ApplyFrutigerMetroDarkAppearance(dialog);
            // Set the dialog gradient after recursive control styling, which also
            // touches ContentDialog.Background.
            dialog.Background = new LinearGradientBrush
            {
                StartPoint = new Point(0, 0),
                EndPoint = new Point(1, 1),
                GradientStops =
                {
                    new GradientStop { Color = ColorHelper.FromArgb(255, 16, 5, 7), Offset = 0 },
                    new GradientStop { Color = ColorHelper.FromArgb(255, 57, 10, 18), Offset = 0.48 },
                    new GradientStop { Color = ColorHelper.FromArgb(255, 8, 4, 6), Offset = 1 }
                }
            };
        }
    }

    private static void FrutigerAeroContentDialog_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is ContentDialog dialog
            && Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && Settings.Current.Theme == WintainiumThemePreference.Light)
        {
            ApplyFrutigerAeroTypography(dialog);
        }
    }

    internal static void ApplyThemePreference()
    {
        foreach (var window in ActiveWindows.Values.ToArray())
        {
            ApplyThemeToWindow(window);
            ApplyVisualStyleToWindow(window);
            RefreshThemeResources(window);

            if (window.Content is FrameworkElement content)
            {
                if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K)
                {
                    QueueY2KTextColorPass(content);
                }
                else if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
                    && Settings.Current.Theme == WintainiumThemePreference.Light)
                {
                    ApplyFrutigerAeroTypography(content, preserveSoftwareCardTypography: window is MainWindow);
                }
            }

            if (window is MainWindow mainWindow)
            {
                mainWindow.RefreshSoftwareCardTextColors();
            }

            if (window is SettingsWindow settingsWindow)
            {
                settingsWindow.RefreshAppearance();
            }
        }
    }


    internal static void ApplyFrutigerMetroDarkAppearance(FrameworkElement root)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.FrutigerAero
            || Settings.Current.Theme != WintainiumThemePreference.Dark)
        {
            return;
        }

        var font = new FontFamily("ms-appx:///Themes/CutieTopRegular-VArx.ttf#Cutie Top");
        var gold = new SolidColorBrush(ColorHelper.FromArgb(255, 0xFF, 0xC9, 0x28));
        ApplyFrutigerMetroDarkElement(root, font, gold);
    }

    private static void ApplyFrutigerMetroDarkElement(FrameworkElement element, FontFamily font, Brush gold)
    {
        switch (element)
        {
            case TextBlock textBlock:
                if (!(textBlock.FontFamily?.Source?.Contains("Segoe MDL2 Assets", StringComparison.OrdinalIgnoreCase) ?? false))
                {
                    textBlock.FontFamily = font;
                    textBlock.Foreground = gold;
                }
                break;
            case Control control:
                if (!(control.FontFamily?.Source?.Contains("Segoe MDL2 Assets", StringComparison.OrdinalIgnoreCase) ?? false))
                {
                    control.FontFamily = font;
                    control.Foreground = gold;
                }
                control.Background = new SolidColorBrush(ColorHelper.FromArgb(210, 38, 8, 13));
                control.BorderBrush = new SolidColorBrush(ColorHelper.FromArgb(255, 255, 90, 31));
                break;
            case Border border:
                border.Background = new SolidColorBrush(ColorHelper.FromArgb(170, 38, 8, 13));
                border.BorderBrush = new SolidColorBrush(ColorHelper.FromArgb(255, 255, 90, 31));
                border.BorderThickness = new Thickness(1);
                break;
        }

        var childCount = Microsoft.UI.Xaml.Media.VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (Microsoft.UI.Xaml.Media.VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyFrutigerMetroDarkElement(child, font, gold);
            }
        }
    }

    internal static void ClearFrutigerMetroDarkAppearance(FrameworkElement root)
    {
        ClearFrutigerMetroDarkAppearanceCore(root);
    }

    private static void ClearFrutigerMetroDarkAppearanceCore(FrameworkElement element)
    {
        static bool IsMetroGold(Brush? brush) =>
            brush is SolidColorBrush solid && solid.Color.A == 255
            && solid.Color.R == 0xFF && solid.Color.G == 0xC9 && solid.Color.B == 0x28;

        static bool IsMetroPanel(Brush? brush, byte alpha) =>
            brush is SolidColorBrush solid && solid.Color.A == alpha
            && solid.Color.R == 38 && solid.Color.G == 8 && solid.Color.B == 13;

        static bool IsMetroEdge(Brush? brush) =>
            brush is SolidColorBrush solid && solid.Color.R == 255
            && solid.Color.G == 90 && solid.Color.B == 31;

        switch (element)
        {
            case TextBlock textBlock:
                if (textBlock.FontFamily?.Source?.Contains("CutieTopRegular-VArx.ttf", StringComparison.OrdinalIgnoreCase) == true
                    || textBlock.FontFamily?.Source?.Contains("Cutie Top", StringComparison.OrdinalIgnoreCase) == true)
                {
                    textBlock.ClearValue(TextBlock.FontFamilyProperty);
                }
                if (IsMetroGold(textBlock.Foreground))
                {
                    textBlock.ClearValue(TextBlock.ForegroundProperty);
                }
                break;
            case Control control:
                if (control.FontFamily?.Source?.Contains("CutieTopRegular-VArx.ttf", StringComparison.OrdinalIgnoreCase) == true
                    || control.FontFamily?.Source?.Contains("Cutie Top", StringComparison.OrdinalIgnoreCase) == true)
                {
                    control.ClearValue(Control.FontFamilyProperty);
                }
                if (IsMetroGold(control.Foreground))
                {
                    control.ClearValue(Control.ForegroundProperty);
                }
                if (IsMetroPanel(control.Background, 210))
                {
                    control.ClearValue(Control.BackgroundProperty);
                }
                if (IsMetroEdge(control.BorderBrush))
                {
                    control.ClearValue(Control.BorderBrushProperty);
                }
                break;
            case Border border:
                if (IsMetroPanel(border.Background, 170)
                    || IsMetroPanel(border.Background, 205)
                    || IsMetroPanel(border.Background, 210))
                {
                    border.ClearValue(Border.BackgroundProperty);
                }
                if (IsMetroEdge(border.BorderBrush))
                {
                    border.ClearValue(Border.BorderBrushProperty);
                    border.ClearValue(Border.BorderThicknessProperty);
                }
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ClearFrutigerMetroDarkAppearanceCore(child);
            }
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

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && Settings.Current.Theme == WintainiumThemePreference.Light)
        {
            var aeroStyle = new ResourceDictionary
            {
                Source = new Uri("ms-appx:///Themes/FrutigerAero-Light.xaml")
            };
            element.Resources.MergedDictionaries.Add(aeroStyle);
            ApplyFrutigerAeroTypography(element);
            if (element is ContentDialog aeroDialog)
            {
                aeroDialog.Loaded -= FrutigerAeroContentDialog_Loaded;
                aeroDialog.Loaded += FrutigerAeroContentDialog_Loaded;
            }
            return;
        }

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && Settings.Current.Theme == WintainiumThemePreference.Dark)
        {
            if (element is ContentDialog metroDialog)
            {
                EnsureFrutigerMetroDialogBackdrop(metroDialog);
            }
            ApplyFrutigerMetroDarkAppearance(element);
            if (element is ContentDialog metroDialogForLoaded)
            {
                metroDialogForLoaded.Loaded -= FrutigerMetroContentDialog_Loaded;
                metroDialogForLoaded.Loaded += FrutigerMetroContentDialog_Loaded;
            }
            return;
        }

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
            WintainiumThemePreference.Light => "Light",
            _ => "Dark"
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
        ApplyY2KContentDialogButtonAreaBackground(dialog);
    }

    private static void ApplyY2KContentDialogButtonAreaBackground(FrameworkElement element)
    {
        var isButtonArea = element.Name is "CommandSpace" or "Button1Host" or "Button2Host" or "Button3Host";
        if (isButtonArea)
        {
            if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K &&
                Settings.Current.Theme == WintainiumThemePreference.Light)
            {
                var chromeBrush = GetY2KLightChromeBrush();
                if (element is Panel panel)
                {
                    panel.Background = chromeBrush;
                }
                else if (element is Border border)
                {
                    border.Background = chromeBrush;
                }
            }
            else
            {
                if (element is Panel panel)
                {
                    panel.ClearValue(Panel.BackgroundProperty);
                }
                else if (element is Border border)
                {
                    border.ClearValue(Border.BackgroundProperty);
                }
            }
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyY2KContentDialogButtonAreaBackground(child);
            }
        }
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
                     fontSource.Contains("Cyberwave2000-Regular.otf", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("Horatio%20D%20Regular.ttf", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("Horatio D Regular.ttf", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("Horatio D", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("CutieTopRegular-VArx.ttf", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("Cutie Top", StringComparison.OrdinalIgnoreCase)))
                {
                    textBlock.ClearValue(TextBlock.FontFamilyProperty);
                }
                break;
            case Control control:
                control.ClearValue(Control.ForegroundProperty);
                if (control.FontFamily?.Source is string controlFontSource &&
                    (controlFontSource.Equals("Consolas", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("Cyberwave2000-Regular.otf", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("Horatio%20D%20Regular.ttf", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("Horatio D Regular.ttf", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("Horatio D", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("CutieTopRegular-VArx.ttf", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("Cutie Top", StringComparison.OrdinalIgnoreCase)))
                {
                    control.ClearValue(Control.FontFamilyProperty);
                }
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

    internal static void ApplyFrutigerAeroTypography(
        FrameworkElement root,
        bool preserveSoftwareCardTypography = false)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.FrutigerAero
            || Settings.Current.Theme != WintainiumThemePreference.Light)
        {
            return;
        }

        var font = new FontFamily("ms-appx:///Horatio%20D%20Regular.ttf#Horatio D");
        var textBrush = new SolidColorBrush(ColorHelper.FromArgb(255, 0x17, 0x4F, 0x67));
        var visited = new HashSet<FrameworkElement>();
        ApplyFrutigerAeroTypographyCore(root, font, textBrush, visited,
            preserveSoftwareCardTypography);
    }

    private static void ApplyFrutigerAeroTypographyCore(
        FrameworkElement element,
        FontFamily font,
        Brush textBrush,
        HashSet<FrameworkElement> visited,
        bool isMainWindowRoot)
    {
        if (!visited.Add(element))
        {
            return;
        }

        switch (element)
        {
            case TextBlock textBlock:
                if (!(textBlock.FontFamily?.Source?.Contains("Segoe MDL2 Assets", StringComparison.OrdinalIgnoreCase) ?? false))
                {
                    textBlock.FontFamily = font;
                    textBlock.Foreground = textBrush;
                    textBlock.FontSize = Math.Max(textBlock.FontSize, 16);
                }
                break;
            case Control control:
                control.FontFamily = font;
                control.Foreground = textBrush;
                control.FontSize = Math.Max(control.FontSize, 16);
                break;
        }

        // ComboBox items may be detached from the visual tree while a popup is closed.
        if (element is ComboBox comboBox)
        {
            foreach (var item in comboBox.Items)
            {
                if (item is FrameworkElement itemElement)
                {
                    ApplyFrutigerAeroTypographyCore(itemElement, font, textBrush, visited, false);
                }
            }
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyFrutigerAeroTypographyCore(child, font, textBrush, visited, isMainWindowRoot);
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

    private static void QueueY2KTextColorPass(FrameworkElement root, int remainingPasses = 8)
    {
        if (remainingPasses <= 0 || Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            return;
        }

        root.DispatcherQueue.TryEnqueue(() =>
        {
            if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
            {
                return;
            }

            ApplyY2KTextColor(root);
            QueueY2KTextColorPass(root, remainingPasses - 1);
        });
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

    internal static Brush GetY2KLightChromeBrush()
    {
        return new LinearGradientBrush
        {
            StartPoint = new Windows.Foundation.Point(0, 0),
            EndPoint = new Windows.Foundation.Point(0, 1),
            GradientStops =
            {
                new GradientStop { Color = ColorHelper.FromArgb(255, 0xF4, 0xF7, 0xF9), Offset = 0 },
                new GradientStop { Color = ColorHelper.FromArgb(255, 0xC7, 0xD2, 0xD9), Offset = 0.22 },
                new GradientStop { Color = ColorHelper.FromArgb(255, 0x71, 0x82, 0x8C), Offset = 0.48 },
                new GradientStop { Color = ColorHelper.FromArgb(255, 0xD9, 0xE2, 0xE7), Offset = 0.70 },
                new GradientStop { Color = ColorHelper.FromArgb(255, 0x8A, 0x9A, 0xA4), Offset = 1 }
            }
        };
    }

    internal static Brush GetY2KLightChromeEdgeBrush() =>
        new SolidColorBrush(ColorHelper.FromArgb(255, 0x60, 0x78, 0x87));

    internal static Brush GetY2KTextBrush()
    {
        if (Settings.Current.Theme != WintainiumThemePreference.Light)
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
        return Settings.Current.Theme != WintainiumThemePreference.Light
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
